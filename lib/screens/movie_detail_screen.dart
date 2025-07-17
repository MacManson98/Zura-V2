import '../widgets/trailer_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../movie.dart';
import '../models/user_profile.dart';
import '../utils/tmdb_api.dart';
import 'package:intl/intl.dart';
import '../utils/debug_loader.dart';


/// Research-driven movie details optimized for user decision making
/// Priority: Genre > Rating > Story > Cast > Visual > Trailer > Year
void showMovieDetails({
  required BuildContext context,
  required Movie movie,
  required UserProfile currentUser,
  Function(Movie)? onAddToFavorites,
  Function(Movie)? onRemoveFromFavorites,
  Function(Movie)? onMarkAsWatched,
  bool isInFavorites = false,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.black,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return FutureBuilder<List<Map<String, String>>>(
          future: _fetchCastDetails(movie),
          builder: (context, snapshot) {
            return Container(
              decoration: BoxDecoration(
                // Extract dominant color from poster for theme
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _getGenreColor(movie.genres).withValues(alpha: 0.1),
                    const Color(0xFF121212),
                  ],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              child: Stack(
                children: [
                  ListView(
                    controller: scrollController,
                    padding: EdgeInsets.all(16.w),
                    children: [
                      // 1. GENRE BADGES - Most important factor
                      _buildGenreSection(movie),
                      
                      SizedBox(height: 16.h),
                      
                      // 2. HERO SECTION - Visual + Core Info
                      _buildHeroSection(movie),
                      
                      SizedBox(height: 20.h),
                      
                      // 3. STORY OVERVIEW - Essential for understanding
                      _buildStorySection(movie),
                      
                      SizedBox(height: 20.h),

                       SizedBox(height: 20.h),
                       _buildStreamingSection(context, movie),

                      // 4. CREATORS
                      
                      _buildCreatorsSection(movie),

                      SizedBox(height: 20.h,),

                      // 5. KEY CAST - Reduces uncertainty
                      _buildCastSection(movie, snapshot.data),
                      
                      SizedBox(height: 20.h),
                      
                      // 6. TRAILER SECTION - Dynamic preview (FIXED - No more crashes!)
                      _buildTrailerSection(movie),
                      
                      SizedBox(height: 20.h),
                      
                      // 7. ACTION BUTTONS - Clear next steps
                      _buildActionButtons(
                        context,
                        movie,
                        onAddToFavorites,
                        onRemoveFromFavorites,
                        onMarkAsWatched,
                        isInFavorites,
                      ),
                      
                      SizedBox(height: 24.h),
                    ],
                  ),
                  
                  // Close button with better contrast
                  Positioned(
                    top: 8.h,
                    right: 8.w,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _getGenreColor(movie.genres).withValues(alpha: 0.3),
                          width: 1.w,
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.close, color: Colors.white, size: 24.sp),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}

// 1. GENRE SECTION - Top priority for user decisions
Widget _buildGenreSection(Movie movie) {
  if (movie.genres.isEmpty) return const SizedBox.shrink();
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(height: 8.h),
      Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: movie.genres.take(4).map((genre) {
          final color = _getGenreColor([genre]);
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.8),
                  color.withValues(alpha: 0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 4.r,
                  offset: Offset(0, 2.h),
                ),
              ],
            ),
            child: Text(
              genre.toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          );
        }).toList(),
      ),
    ],
  );
}

// 2. HERO SECTION - Visual appeal + core info
Widget _buildHeroSection(Movie movie) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Large, prominent poster - visual decision factor
      Container(
        width: 140.w,
        height: 210.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: _getGenreColor(movie.genres).withValues(alpha: 0.4),
              blurRadius: 12.r,
              offset: Offset(0, 6.h),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: Image.network(
            movie.posterUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: const Color(0xFF1F1F1F),
                child: Center(
                  child: CircularProgressIndicator(
                    color: _getGenreColor(movie.genres),
                    strokeWidth: 2.w,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: const Color(0xFF1F1F1F),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.movie,
                      size: 40.sp,
                      color: Colors.white54,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'No Image',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      
      SizedBox(width: 16.w),
      
      // Title and essential metadata
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Movie title - prominent and readable
            Text(
              movie.title,
              style: TextStyle(
                fontSize: 26.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.2,
              ),
            ),
            
            SizedBox(height: 12.h),
            
            // Quick facts that matter for decisions
            if (movie.releaseDate != null && movie.releaseDate!.isNotEmpty)
              _buildQuickFact(
                icon: Icons.calendar_today_rounded,
                text: _getYearFromDate(movie.releaseDate!),
                color: Colors.blue,
              ),
            
            if (movie.runtime != null && movie.runtime! > 0)
              _buildQuickFact(
                icon: Icons.schedule_rounded,
                text: _formatRuntime(movie.runtime!),
                color: Colors.green,
              ),
            
            if (movie.rating != null)
              _buildQuickFact(
                icon: Icons.star_rounded,
                text: '${movie.rating!.toStringAsFixed(1)} / 10 — ${_getRatingDescription(movie.rating!)}',
                color: Colors.amber,
              ),
            if (movie.originalLanguage != null)
              _buildQuickFact(
                icon: Icons.language_rounded,
                text: toBeginningOfSentenceCase(movie.originalLanguage!) ?? movie.originalLanguage!,
                color: Colors.lightBlue,
              ),
          ],
        ),
      ),
    ],
  );
}

// 3. STORY SECTION - Essential for understanding
Widget _buildStorySection(Movie movie) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(
            Icons.auto_stories_rounded,
            color: _getGenreColor(movie.genres),
            size: 20.sp,
          ),
          SizedBox(width: 8.w),
          Text(
            "What's it about?",
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
      SizedBox(height: 12.h),
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: _getGenreColor(movie.genres).withValues(alpha: 0.2),
            width: 1.w,
          ),
        ),
        child: Text(
          movie.overview.isNotEmpty 
              ? movie.overview 
              : "Plot details are not available for this movie.",
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 15.sp,
            height: 1.5,
          ),
        ),
      ),
    ],
  );
}

// 4. CREATORS SECTION
Widget _buildCreatorsSection(Movie movie) {
  final genreColor = _getGenreColor(movie.genres);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(Icons.edit_rounded, color: genreColor, size: 20.sp),
          SizedBox(width: 8.w),
          Text(
            "Created by",
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
      SizedBox(height: 12.h),
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: genreColor.withValues(alpha: 0.2),
            width: 1.w,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (movie.directors.isNotEmpty)
              Text(
                "Director${movie.directors.length > 1 ? 's' : ''}: ${movie.directors.join(', ')}",
                style: TextStyle(color: Colors.white70, fontSize: 14.sp),
              ),
            if (movie.writers.isNotEmpty) ...[
              SizedBox(height: 8.h),
              Text(
                "Writer${movie.writers.length > 1 ? 's' : ''}: ${movie.writers.join(', ')}",
                style: TextStyle(color: Colors.white70, fontSize: 14.sp),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

// 5. CAST SECTION - Reduces uncertainty with familiar faces
Widget _buildCastSection(Movie movie, List<Map<String, String>>? castDetails) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(
            Icons.groups_rounded,
            color: _getGenreColor(movie.genres),
            size: 20.sp,
          ),
          SizedBox(width: 8.w),
          Text(
            "Starring",
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
      SizedBox(height: 12.h),
      
      if (castDetails != null && castDetails.isNotEmpty)
        SizedBox(
          height: 100.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: castDetails.take(6).length,
            itemBuilder: (context, index) {
              final actor = castDetails[index];
              return Container(
                width: 80.w,
                margin: EdgeInsets.only(right: 12.w),
                child: Column(
                  children: [
                    Container(
                      width: 60.w,
                      height: 60.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _getGenreColor(movie.genres).withValues(alpha: 0.3),
                          width: 2.w,
                        ),
                      ),
                      child: ClipOval(
                        child: actor['profilePath']!.isNotEmpty
                            ? Image.network(
                                actor['profilePath']!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildActorFallback(actor['name']!),
                              )
                            : _buildActorFallback(actor['name']!),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      actor['name']!,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        )
      else if (movie.cast.isNotEmpty)
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: movie.cast.take(4).map((actor) {
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: _getGenreColor(movie.genres).withValues(alpha: 0.3),
                  width: 1.w,
                ),
              ),
              child: Text(
                actor,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        )
      else
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Text(
            "Cast information not available",
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14.sp,
            ),
            textAlign: TextAlign.center,
          ),
        ),
    ],
  );
}

// 6. TRAILER SECTION - FIXED! Now uses safe TrailerPlayerWidget
Widget _buildTrailerSection(Movie movie) {
  return Container(
    margin: EdgeInsets.fromLTRB(24.w, 0, 24.w, 32.h),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.play_circle_fill_rounded,
              color: _getGenreColor(movie.genres),
              size: 20.sp,
            ),
            SizedBox(width: 8.w),
            Text(
              "Watch Trailer",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        
        // Safe trailer player - no embedded video, no crashes!
        TrailerPlayerWidget(
          movie: movie,
          autoPlay: false,
          showControls: true,
        ),
      ],
    ),
  );
}

// 7. ACTION BUTTONS - Clear next steps
Widget _buildActionButtons(
  BuildContext context,
  Movie movie,
  Function(Movie)? onAddToFavorites,
  Function(Movie)? onRemoveFromFavorites,
  Function(Movie)? onMarkAsWatched,
  bool isInFavorites,
) {
  final primaryColor = _getGenreColor(movie.genres);
  
  return Column(
    children: [
      // Primary action button
      if (onAddToFavorites != null && !isInFavorites)
        SizedBox(
          width: double.infinity,
          height: 56.h,
          child: ElevatedButton.icon(
            onPressed: () {
              onAddToFavorites(movie);
              Navigator.pop(context);
            },
            icon: Icon(Icons.favorite_rounded, size: 20.sp),
            label: Text(
              'Add to Favorites',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              elevation: 4,
            ),
          ),
        ),
        
      if (isInFavorites && onRemoveFromFavorites != null)
        SizedBox(
          width: double.infinity,
          height: 56.h,
          child: OutlinedButton.icon(
            onPressed: () {
              onRemoveFromFavorites(movie);
              Navigator.pop(context);
            },
            icon: Icon(Icons.heart_broken_rounded, size: 20.sp),
            label: Text(
              'Remove from Liked',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: BorderSide(color: Colors.red, width: 2.w),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
          ),
        ),
        
      // Secondary action
      if (onMarkAsWatched != null) ...[
        SizedBox(height: 12.h),
        SizedBox(
          width: double.infinity,
          height: 48.h,
          child: OutlinedButton.icon(
            onPressed: () {
              onMarkAsWatched(movie);
              Navigator.pop(context);
            },
            icon: Icon(Icons.visibility_rounded, size: 18.sp),
            label: Text(
              'Mark as Watched',
              style: TextStyle(fontSize: 14.sp),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              side: BorderSide(color: Colors.green, width: 1.w),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

// HELPER FUNCTIONS

Widget _buildQuickFact({
  required IconData icon,
  required String text,
  required Color color,
}) {
  return Padding(
    padding: EdgeInsets.only(bottom: 8.h),
    child: Row(
      children: [
        Icon(icon, color: color, size: 16.sp),
        SizedBox(width: 8.w),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

Widget _buildActorFallback(String name) {
  return Container(
    color: const Color(0xFF2A2A2A),
    child: Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

Widget _buildStreamingSection(BuildContext context, Movie movie) {
    DebugLogger.log('🎬 Movie: ${movie.title}');
  DebugLogger.log('🔍 hasAnyStreamingOptions: ${movie.hasAnyStreamingOptions}');
  DebugLogger.log('🔍 allServices: ${movie.allServices}');
  DebugLogger.log('🔍 availableOn: ${movie.availableOn}');
  DebugLogger.log('🔍 rentOn: ${movie.rentOn}');
  DebugLogger.log('🔍 buyOn: ${movie.buyOn}');
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
            // Free streaming options
            if (movie.hasAvailableStreaming)
              _buildCollapsibleStreamingSection(
                title: "Stream Free",
                platforms: movie.availableOn,
                color: Colors.green,
                icon: Icons.play_circle_fill,
                type: 'watch',
                context: context
              ),
            
            // Rental options
            if (movie.hasRentalOptions)
              _buildCollapsibleStreamingSection(
                title: "Rent",
                platforms: movie.rentOn,
                color: Colors.orange,
                icon: Icons.money,
                type: 'rent',
                context: context
              ),
            
            // Purchase options
            if (movie.hasPurchaseOptions)
              _buildCollapsibleStreamingSection(
                title: "Buy",
                platforms: movie.buyOn,
                color: Colors.blue,
                icon: Icons.shopping_cart,
                type: 'buy',
                context: context
              ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 48.sp,
                  ),
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
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14.sp,
                    ),
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
    required String title,
    required List<String> platforms,
    required Color color,
    required IconData icon,
    required String type,
    required BuildContext context,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
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
                      onPressed: () => _openStreamingPlatform(platform, type),
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


// Genre-based theming
Color _getGenreColor(List<String> genres) {
  if (genres.isEmpty) return const Color(0xFFE5A00D);
  
  final genre = genres.first.toLowerCase();
  switch (genre) {
    case 'action':
      return Colors.red;
    case 'comedy':
      return Colors.orange;
    case 'drama':
      return Colors.blue;
    case 'horror':
      return Colors.deepPurple;
    case 'romance':
      return Colors.pink;
    case 'sci-fi':
    case 'science fiction':
      return Colors.cyan;
    case 'fantasy':
      return Colors.purple;
    case 'thriller':
      return Colors.indigo;
    case 'mystery':
      return Colors.teal;
    case 'animation':
      return Colors.green;
    case 'documentary':
      return Colors.brown;
    case 'crime':
      return Colors.grey;
    default:
      return const Color(0xFFE5A00D);
  }
  
}

String _getRatingDescription(double rating) {
  if (rating >= 8.5) return "Exceptional";
  if (rating >= 8.0) return "Excellent";
  if (rating >= 7.5) return "Very Good";
  if (rating >= 7.0) return "Good";
  if (rating >= 6.0) return "Decent";
  if (rating >= 5.0) return "Mixed Reviews";
  return "Poor";
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

// Helper method to fetch cast details from TMDB
Future<List<Map<String, String>>> _fetchCastDetails(Movie movie) async {
  try {
    final movieId = await TMDBApi.searchMovieId(movie.title);
    if (movieId != null) {
      return await TMDBApi.getMovieCast(movieId);
    }
  } catch (e) {
    DebugLogger.log('Error fetching cast details: $e');
  }
  return [];
}

void _openStreamingPlatform(String platform, String type) async {
  final query = Uri.encodeComponent('$platform $type movie');
  final url = Uri.parse('https://www.google.com/search?q=$query');
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  } else {
    DebugLogger.log('Could not launch $url');
  }
}

String _formatPlatformName(String platform) {
  final normalized = platform.toLowerCase();
  if (normalized.contains('amazon')) return 'Amazon Prime';
  if (normalized.contains('netflix')) return 'Netflix';
  if (normalized.contains('disney')) return 'Disney+';
  if (normalized.contains('hulu')) return 'Hulu';
  if (normalized.contains('itunes')) return 'Apple TV';
  if (normalized.contains('sky')) return 'Sky';
  if (normalized.contains('now')) return 'NOW TV';
  if (normalized.contains('google')) return 'Google Play';
  return platform;
}