// File: lib/screens/watch_options_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../movie.dart';
import '../models/user_profile.dart';
import '../utils/themed_notifications.dart';
import '../widgets/trailer_player_widget.dart';
import '../utils/debug_loader.dart';

class WatchOptionsScreen extends StatefulWidget {
  final Movie movie;
  final UserProfile currentUser;
  final String? matchedName;
  final List<String>? allMatchedUsers;
  final VoidCallback? onContinueSession;
  final Function(Movie)? onRemoveFromFavorites;

  const WatchOptionsScreen({
    super.key,
    required this.movie,
    required this.currentUser,
    this.matchedName,
    this.allMatchedUsers,
    this.onContinueSession,
    this.onRemoveFromFavorites,
  });

  @override
  State<WatchOptionsScreen> createState() => _WatchOptionsScreenState();
}

class _WatchOptionsScreenState extends State<WatchOptionsScreen> {
  
  @override
  Widget build(BuildContext context) {
    final isCollaborative = widget.matchedName != null || 
                          (widget.allMatchedUsers != null && widget.allMatchedUsers!.length > 1);
    
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: CustomScrollView(
        slivers: [
          // Hero section with poster and back button
          SliverAppBar(
            expandedHeight: 400.h,
            pinned: true,
            backgroundColor: const Color(0xFF121212),
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeroSection(),
            ),
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white,
                  size: 20.sp,
                ),
              ),
            ),
          ),
          
          // Content
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Movie title and basic info
                _buildMovieHeader(),
                
                // Streaming options (main focus)
                _buildStreamingSection(),
                
                // Trailer section
                _buildTrailerSection(),
                
                // Quick details
                _buildQuickDetails(),
                
                // Plot summary
                _buildPlotSection(),
                
                // Action buttons
                _buildActionButtons(isCollaborative),
                
                SizedBox(height: 32.h),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      height: 400.h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background poster with overlay
          Image.network(
            widget.movie.posterUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFF1F1F1F),
              child: Icon(
                Icons.movie,
                size: 100.sp,
                color: Colors.white30,
              ),
            ),
          ),
          
          // Gradient overlay
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

  Widget _buildMovieHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            widget.movie.title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28.sp,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          
          SizedBox(height: 12.h),
          
          // Quick facts row
          Row(
            children: [
              if (widget.movie.rating != null) ...[
                Icon(Icons.star, color: Colors.amber, size: 16.sp),
                SizedBox(width: 4.w),
                Text(
                  widget.movie.rating!.toStringAsFixed(1),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 16.w),
              ],
              
              if (widget.movie.releaseDate != null) ...[
                Text(
                  _getYearFromDate(widget.movie.releaseDate!),
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16.sp,
                  ),
                ),
                SizedBox(width: 16.w),
              ],
              
              if (widget.movie.runtime != null) ...[
                Text(
                  _formatRuntime(widget.movie.runtime!),
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16.sp,
                  ),
                ),
              ],
            ],
          ),
          
          SizedBox(height: 12.h),
          
          // Genres
          if (widget.movie.genres.isNotEmpty)
            Wrap(
              spacing: 8.w,
              children: widget.movie.genres.take(3).map((genre) {
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

  Widget _buildStreamingSection() {
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
          
          if (widget.movie.hasAnyStreamingOptions) ...[
            // Free streaming options
            if (widget.movie.hasAvailableStreaming)
              _buildCollapsibleStreamingSection(
                title: "Stream Free",
                platforms: widget.movie.availableOn,
                color: Colors.green,
                icon: Icons.play_circle_fill,
                type: 'watch',
              ),
            
            // Rental options
            if (widget.movie.hasRentalOptions)
              _buildCollapsibleStreamingSection(
                title: "Rent",
                platforms: widget.movie.rentOn,
                color: Colors.orange,
                icon: Icons.money,
                type: 'rent',
              ),
            
            // Purchase options
            if (widget.movie.hasPurchaseOptions)
              _buildCollapsibleStreamingSection(
                title: "Buy",
                platforms: widget.movie.buyOn,
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

  Widget _buildTrailerSection() {
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
          
          // Trailer player
          TrailerPlayerWidget(
            movie: widget.movie,
            autoPlay: false,
            showControls: true,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDetails() {
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
          
          if (widget.movie.directors.isNotEmpty) ...[
            _buildDetailRow("Director", widget.movie.directors.join(", ")),
            SizedBox(height: 8.h),
          ],
          
          if (widget.movie.cast.isNotEmpty) ...[
            _buildDetailRow("Starring", widget.movie.cast.take(3).join(", ")),
            SizedBox(height: 8.h),
          ],
          
          if (widget.movie.originalLanguage != null) ...[
            _buildDetailRow("Language", widget.movie.originalLanguage!),
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
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlotSection() {
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
              widget.movie.overview.isNotEmpty 
                  ? widget.movie.overview 
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

  Widget _buildActionButtons(bool isCollaborative) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        children: [
          // Primary action - Add to favorites
          SizedBox(
            width: double.infinity,
            height: 56.h,
            child: ElevatedButton.icon(
              onPressed: () => _addToFavorites(),
              icon: Icon(Icons.favorite, size: 24.sp),
              label: Text(
                'Add to Likes',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5A00D),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                elevation: 4,
              ),
            ),
          ),
          
          SizedBox(height: 16.h),
          
          // Secondary action - Continue session
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: OutlinedButton.icon(
              onPressed: widget.onContinueSession ?? () => Navigator.pop(context),
              icon: Icon(Icons.add, size: 20.sp),
              label: Text(
                'Continue finding tonight!',
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

  // Helper methods
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

  Future<void> _openStreamingPlatform(String platform, String type) async {
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
        url = 'https://www.google.com/search?q=${Uri.encodeComponent("$actionText ${widget.movie.title} on $platform")}';
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

  void _addToFavorites() {
    if (!widget.currentUser.likedMovieIds.contains(widget.movie.id)) {
      widget.currentUser.likedMovies.add(widget.movie);
      widget.currentUser.likedMovieIds.add(widget.movie.id);
      
      ThemedNotifications.showSuccess(
        context,
        '${widget.movie.title} added to favorites',
        icon: '❤️',
      );
    } else {
      ThemedNotifications.showInfo(
        context,
        '${widget.movie.title} is already in your favorites',
        icon: '📋',
      );
    }
  }
}