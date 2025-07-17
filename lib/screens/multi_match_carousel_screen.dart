// File: lib/screens/multi_match_carousel_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../movie.dart';
import '../models/user_profile.dart';
import '../models/session_models.dart';
import '../utils/themed_notifications.dart';
import '../widgets/trailer_player_widget.dart';
import '../utils/debug_loader.dart';
import '../utils/movie_loader.dart';
import 'package:glassmorphism/glassmorphism.dart';

class MultiMatchCarouselScreen extends StatefulWidget {
  final SwipeSession session;
  final UserProfile currentUser;
  final VoidCallback? onContinueSearching;

  const MultiMatchCarouselScreen({
    super.key,
    required this.session,
    required this.currentUser,
    this.onContinueSearching,
  });

  @override
  State<MultiMatchCarouselScreen> createState() => _MultiMatchCarouselScreenState();
}

class _MultiMatchCarouselScreenState extends State<MultiMatchCarouselScreen> 
    with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentIndex = 0;
  List<Movie> _matchedMovies = [];
  bool _isLoading = true;
  bool _showSwipeHint = true;
  late AnimationController _hintController;
  late Animation<double> _hintAnimation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _hintController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _hintAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _hintController, curve: Curves.easeInOut),
    );
    
    _loadMatchedMovies();
    _initializeSwipeHint();
  }

  void _initializeSwipeHint() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _matchedMovies.length > 1) {
        _hintController.forward();
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showSwipeHint = false;
            });
          }
        });
      }
    });
  }

  Future<void> _loadMatchedMovies() async {
    try {
      final movieDatabase = await MovieDatabaseLoader.loadMovieDatabase();
      final matchedMovies = <Movie>[];
      
      for (final movieId in widget.session.matches) {
        try {
          final movie = movieDatabase.firstWhere((m) => m.id == movieId);
          matchedMovies.add(movie);
        } catch (e) {
          DebugLogger.log("⚠️ Could not find movie for ID: $movieId");
        }
      }
      
      if (mounted) {
        setState(() {
          _matchedMovies = matchedMovies;
          _isLoading = false;
        });

        _initializeSwipeHint();
      }
    } catch (e) {
      DebugLogger.log("❌ Error loading matched movies: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  Widget _buildSwipeHint() {
    if (!_showSwipeHint || _matchedMovies.length <= 1) {
      return const SizedBox.shrink();
    }
    
    return AnimatedBuilder(
      animation: _hintAnimation,
      builder: (context, child) {
        return Positioned.fill(
          child: Center(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 40.w),
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85 * _hintAnimation.value),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: const Color(0xFFE5A00D).withValues(alpha: 0.8 * _hintAnimation.value),
                  width: 2.w,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4 * _hintAnimation.value),
                    blurRadius: 20.r,
                    spreadRadius: 4.r,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Swipe icon with animation
                  Container(
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5A00D).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.swipe,
                      color: const Color(0xFFE5A00D),
                      size: 32.sp,
                    ),
                  ),
                  
                  SizedBox(height: 16.h),
                  
                  // Main text
                  Text(
                    "Swipe to explore matches",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  SizedBox(height: 8.h),
                  
                  // Subtitle
                  Text(
                    "Found ${_matchedMovies.length} perfect matches!\nSwipe left or right to see them all",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  SizedBox(height: 20.h),
                  
                  // Dismiss button
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showSwipeHint = false;
                      });
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFE5A00D).withValues(alpha: 0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        side: BorderSide(
                          color: const Color(0xFFE5A00D).withValues(alpha: 0.6),
                          width: 1.w,
                        ),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                    ),
                    child: Text(
                      "Got it!",
                      style: TextStyle(
                        color: const Color(0xFFE5A00D),
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Movie-themed header with navigation controls
  // Replace your _buildMovieThemedHeader() method with this:
  Widget _buildMovieThemedHeader() {
  return GlassmorphicContainer(
    width: double.infinity,
    height: 80.h,
    borderRadius: 0,
    blur: 15,
    alignment: Alignment.bottomCenter,
    border: 0,
    linearGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: 0.05),
        Colors.white.withValues(alpha: 0.02),
      ],
    ),
    borderGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: 0.2),
        Colors.white.withValues(alpha: 0.05),
      ],
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
        child: Row(
          children: [
            // Back button
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: GlassmorphicContainer(
                    width: 120.w,
                    height: 32.h,
                    borderRadius: 8,
                    blur: 4,
                    alignment: Alignment.center,
                    border: 1,
                    linearGradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.3),
                        Colors.white.withValues(alpha: 0.1),
                      ],
                    ),
                    borderGradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.8),
                        Colors.white.withValues(alpha: 0.3),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 12.sp,
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          "Back to Matcher",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Counter
            Expanded(
              flex: 1,
              child: Center(
                child: GlassmorphicContainer(
                  width: 70.w,
                  height: 32.h,
                  borderRadius: 16,
                  blur: 4,
                  alignment: Alignment.center,
                  border: 1,
                  linearGradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.9),
                      Colors.white.withValues(alpha: 0.7),
                    ],
                  ),
                  borderGradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 1.0),
                      Colors.white.withValues(alpha: 0.4),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.movie,
                        color: Colors.black87,
                        size: 12.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        "${_currentIndex + 1} of ${_matchedMovies.length}",
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Navigation arrows
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerRight,
                child: _matchedMovies.length > 1 
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _currentIndex > 0 ? () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } : null,
                            child: GlassmorphicContainer(
                              width: 32.w,
                              height: 32.h,
                              borderRadius: 6,
                              blur: 4,
                              alignment: Alignment.center,
                              border: 1,
                              linearGradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: _currentIndex > 0 
                                    ? [
                                        Colors.white.withValues(alpha: 0.3),
                                        Colors.white.withValues(alpha: 0.1),
                                      ]
                                    : [
                                        Colors.white.withValues(alpha: 0.1),
                                        Colors.white.withValues(alpha: 0.05),
                                      ],
                              ),
                              borderGradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: _currentIndex > 0 ? 0.8 : 0.3),
                                  Colors.white.withValues(alpha: _currentIndex > 0 ? 0.3 : 0.1),
                                ],
                              ),
                              child: Icon(
                                Icons.chevron_left,
                                color: _currentIndex > 0 
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.4),
                                size: 16.sp,
                              ),
                            ),
                          ),
                          
                          SizedBox(width: 4.w),
                          
                          GestureDetector(
                            onTap: _currentIndex < _matchedMovies.length - 1 ? () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } : null,
                            child: GlassmorphicContainer(
                              width: 32.w,
                              height: 32.h,
                              borderRadius: 6,
                              blur: 4,
                              alignment: Alignment.center,
                              border: 1,
                              linearGradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: _currentIndex < _matchedMovies.length - 1
                                    ? [
                                        Colors.white.withValues(alpha: 0.3),
                                        Colors.white.withValues(alpha: 0.1),
                                      ]
                                    : [
                                        Colors.white.withValues(alpha: 0.1),
                                        Colors.white.withValues(alpha: 0.05),
                                      ],
                              ),
                              borderGradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: _currentIndex < _matchedMovies.length - 1 ? 0.8 : 0.3),
                                  Colors.white.withValues(alpha: _currentIndex < _matchedMovies.length - 1 ? 0.3 : 0.1),
                                ],
                              ),
                              child: Icon(
                                Icons.chevron_right,
                                color: _currentIndex < _matchedMovies.length - 1
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.4),
                                size: 16.sp,
                              ),
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
  // Simple page dots at bottom
  Widget _buildPageDots() {
    if (_matchedMovies.length <= 1) return const SizedBox.shrink();
    
    return Positioned(
      bottom: 30.h,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_matchedMovies.length, (index) {
          final isActive = index == _currentIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isActive ? 24.w : 8.w,
            height: 8.h,
            margin: EdgeInsets.symmetric(horizontal: 4.w),
            decoration: BoxDecoration(
              color: isActive 
                  ? const Color(0xFFE5A00D)
                  : Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4.r),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFFE5A00D)),
              SizedBox(height: 16.h),
              Text(
                "Loading your matches...",
                style: TextStyle(color: Colors.white70, fontSize: 16.sp),
              ),
            ],
          ),
        ),
      );
    }

    if (_matchedMovies.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.movie_outlined, size: 64.sp, color: Colors.white30),
              SizedBox(height: 16.h),
              Text(
                "No matches found",
                style: TextStyle(color: Colors.white, fontSize: 18.sp),
              ),
              SizedBox(height: 32.h),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Go Back"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          // Fullscreen PageView
          PageView.builder(
            controller: _pageController,
            itemCount: _matchedMovies.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
                _showSwipeHint = false;
              });
            },
            itemBuilder: (context, index) {
              final movie = _matchedMovies[index];

              return CustomScrollView(
                slivers: [
                  // 🎬 Poster Hero at top
                  SliverToBoxAdapter(
                    child: Stack(
                      children: [
                        _buildMovieHero(movie), // ← ONLY poster
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: _buildMovieThemedHeader(), // ← Glass header over it
                        ),
                      ],
                    ),
                  ),

                  // 📦 Rest of the content
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildMovieHeader(movie),
                        _buildStreamingSection(movie),
                        _buildTrailerSection(movie),
                        _buildQuickDetails(movie),
                        _buildPlotSection(movie),
                        _buildActionButtons(movie),
                        SizedBox(height: 80.h),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          // 🎯 Overlay: Dots + Swipe Hint
          _buildPageDots(),
          _buildSwipeHint(),
        ],
      ),
    );
  }


  // Movie hero section (same as before but cleaner)
  Widget _buildMovieHero(Movie movie) {
  return Container(
    width: double.infinity,
    height: 350.h,
    margin: EdgeInsets.only(top: 60.h), // ← Moves entire container down
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          movie.posterUrl,
          fit: BoxFit.cover,
          height: 350.h,
          width: double.infinity,
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.3),
                Colors.black.withValues(alpha: 0.8),
                const Color(0xFF121212),
              ],
              stops: const [0.0, 0.4, 0.8, 1.0],
            ),
          ),
        ),
      ],
    ),
  );
}

  // All the same content methods from before (unchanged)
  Widget _buildMovieHeader(Movie movie) {
    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            movie.title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28.sp,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              if (movie.rating != null) ...[
                Icon(Icons.star, color: Colors.amber, size: 16.sp),
                SizedBox(width: 4.w),
                Text(
                  movie.rating!.toStringAsFixed(1),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 16.w),
              ],
              if (movie.releaseDate != null) ...[
                Text(
                  _getYearFromDate(movie.releaseDate!),
                  style: TextStyle(color: Colors.white70, fontSize: 16.sp),
                ),
                SizedBox(width: 16.w),
              ],
              if (movie.runtime != null) ...[
                Text(
                  _formatRuntime(movie.runtime!),
                  style: TextStyle(color: Colors.white70, fontSize: 16.sp),
                ),
              ],
            ],
          ),
          SizedBox(height: 12.h),
          if (movie.genres.isNotEmpty)
            Wrap(
              spacing: 8.w,
              children: movie.genres.take(3).map((genre) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5A00D).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: const Color(0xFFE5A00D).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    genre.toUpperCase(),
                    style: TextStyle(
                      color: const Color(0xFFE5A00D),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildStreamingSection(Movie movie) {
    return Container(
      margin: EdgeInsets.fromLTRB(24.w, 0, 24.w, 32.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Where to Watch",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16.h),
          
          if (movie.hasAnyStreamingOptions) ...[
            if (movie.hasAvailableStreaming)
              _buildCollapsibleStreamingSection(
                movie: movie,
                title: "Stream Free",
                platforms: movie.availableOn,
                color: Colors.green,
                icon: Icons.play_circle_fill,
                type: 'watch',
              ),
            if (movie.hasRentalOptions)
              _buildCollapsibleStreamingSection(
                movie: movie,
                title: "Rent",
                platforms: movie.rentOn,
                color: Colors.orange,
                icon: Icons.money,
                type: 'rent',
              ),
            if (movie.hasPurchaseOptions)
              _buildCollapsibleStreamingSection(
                movie: movie,
                title: "Buy",
                platforms: movie.buyOn,
                color: Colors.blue,
                icon: Icons.shopping_cart,
                type: 'buy',
              ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48.sp),
                  SizedBox(height: 16.h),
                  Text(
                    "Not Currently Available",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    "This movie isn't available on major streaming platforms right now",
                    style: TextStyle(color: Colors.white70, fontSize: 14.sp),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollapsibleStreamingSection({
    required Movie movie,
    required String title,
    required List<String> platforms,
    required Color color,
    required IconData icon,
    required String type,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, color: color, size: 24.sp),
          title: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '${platforms.length}',
                  style: TextStyle(
                    color: color,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          iconColor: color,
          collapsedIconColor: color,
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
              child: Column(
                children: platforms.map((platform) {
                  return Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(bottom: 8.h),
                    child: ElevatedButton.icon(
                      onPressed: () => _openStreamingPlatform(movie, platform, type),
                      icon: Icon(icon, size: 20.sp),
                      label: Text(
                        '${type.toUpperCase()} on ${_formatPlatformName(platform)}',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        elevation: 2,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrailerSection(Movie movie) {
    return Container(
      margin: EdgeInsets.fromLTRB(24.w, 0, 24.w, 32.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Preview",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16.h),
          TrailerPlayerWidget(
            movie: movie,
            autoPlay: false,
            showControls: true,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDetails(Movie movie) {
    return Container(
      margin: EdgeInsets.fromLTRB(24.w, 0, 24.w, 32.h),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Details",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),
          if (movie.directors.isNotEmpty) ...[
            _buildDetailRow("Director", movie.directors.join(", ")),
            SizedBox(height: 8.h),
          ],
          if (movie.cast.isNotEmpty) ...[
            _buildDetailRow("Starring", movie.cast.take(3).join(", ")),
            SizedBox(height: 8.h),
          ],
          if (movie.originalLanguage != null) ...[
            _buildDetailRow("Language", movie.originalLanguage!),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80.w,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: Colors.white, fontSize: 14.sp),
          ),
        ),
      ],
    );
  }

  Widget _buildPlotSection(Movie movie) {
    return Container(
      margin: EdgeInsets.fromLTRB(24.w, 0, 24.w, 32.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Plot",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Text(
              movie.overview.isNotEmpty 
                  ? movie.overview 
                  : "Plot details are not available for this movie.",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 16.sp,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Movie movie) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56.h,
            child: ElevatedButton.icon(
              onPressed: () => _endSession(),
              icon: Icon(Icons.check_circle, size: 24.sp),
              label: Text(
                'End Session - We Found It!',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                elevation: 4,
              ),
            ),
          ),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: OutlinedButton.icon(
              onPressed: widget.onContinueSearching ?? () => Navigator.pop(context),
              icon: Icon(Icons.add, size: 20.sp),
              label: Text(
                'Keep Looking for More',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 2.w),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods (same as before)
  String _formatPlatformName(String platform) {
    switch (platform.toLowerCase()) {
      case 'amazon video':
        return 'Prime Video';
      case 'google play movies':
        return 'Google Play';
      case 'apple tv':
        return 'Apple TV';
      case 'fandango at home':
        return 'Fandango';
      case 'youtube':
        return 'YouTube';
      default:
        return platform;
    }
  }

  String _formatRuntime(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  String _getYearFromDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return date.year.toString();
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _openStreamingPlatform(Movie movie, String platform, String type) async {
    String url = '';
    String actionText = '';

    switch (type) {
      case 'watch':
        actionText = 'Stream';
        break;
      case 'rent':
        actionText = 'Rent';
        break;
      case 'buy':
        actionText = 'Buy';
        break;
    }

    switch (platform.toLowerCase()) {
      case 'netflix':
        url = 'https://www.netflix.com';
        break;
      case 'amazon video':
        url = 'https://www.amazon.com/gp/video';
        break;
      case 'apple tv':
        url = 'https://tv.apple.com';
        break;
      case 'google play movies':
        url = 'https://play.google.com/store/movies';
        break;
      case 'youtube':
        url = 'https://www.youtube.com';
        break;
      case 'hulu':
        url = 'https://www.hulu.com';
        break;
      case 'disney+':
      case 'disney plus':
        url = 'https://www.disneyplus.com';
        break;
      case 'hbo max':
      case 'max':
        url = 'https://www.max.com';
        break;
      default:
        url = 'https://www.google.com/search?q=${Uri.encodeComponent("$actionText ${movie.title} on $platform")}';
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ThemedNotifications.showError(
            context,
            'Could not open ${_formatPlatformName(platform)}',
          );
        }
      }
    } catch (e) {
      DebugLogger.log('Error launching streaming app: $e');
    }
  }

  void _endSession() {
    // Show confirmation dialog first
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F1F1F),
          title: Text(
            'End Session?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'This will end the movie matching session for all participants. Are you sure?',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16.sp,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16.sp,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _performEndSession();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'End Session',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _performEndSession() {
    ThemedNotifications.showSuccess(
      context,
      'Session ended successfully!',
      icon: '✅',
    );
    
    // Navigate back to home or main screen
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}