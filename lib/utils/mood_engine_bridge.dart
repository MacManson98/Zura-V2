// Updated Mood Engine Bridge with Smart Session Flow Integration
// Maintains compatibility while adding intelligent session ordering

import '../movie.dart';
import '../models/user_profile.dart';
import '../utils/debug_loader.dart';
import 'mood_engine.dart';
import 'smart_session_flow.dart';

// Re-export the enums and classes from enhanced engine
export 'mood_engine.dart' show CurrentMood, SessionContext, EnhancedMoodEngine;
export 'smart_session_flow.dart' show SmartSessionFlow;

class MoodBasedLearningEngine {
  
  // Session state tracking for mood changes
  static CurrentMood? _lastSessionMood;
  static int _currentSwipeCount = 0;
  static List<Movie>? _lastGeneratedSession;
  
  /// Main mood session generator with smart ordering
  static Future<List<Movie>> generateMoodBasedSession({
    required UserProfile user,
    required List<Movie> movieDatabase,
    required SessionContext sessionContext,
    required Set<String> seenMovieIds,
    required Set<String> sessionPassedMovieIds,
    int sessionSize = 30,
    bool useSmartOrdering = true,
  }) async {
    DebugLogger.log("🎭 Generating enhanced mood session: ${sessionContext.moods.displayName}");
    
    // Step 1: Filter movies using enhanced mood engine
    final moodFilteredMovies = EnhancedMoodEngine.filterByMoodCriteria(
      movieDatabase, 
      sessionContext.moods, 
      seenMovieIds, 
      sessionPassedMovieIds
    );
    
    if (moodFilteredMovies.isEmpty) {
      DebugLogger.log("⚠️ No movies found for mood, using fallback");
      return _getFallbackMovies(movieDatabase, seenMovieIds, sessionSize);
    }
    
    List<Movie> result;
    
    // Step 2: Check if we should reorder existing session or create new one
    if (useSmartOrdering && _shouldReorderExistingSession(sessionContext.moods)) {
      DebugLogger.log("🔄 Reordering existing session for mood change");
      result = SmartSessionFlow.reorderForMoodChange(
        currentSession: _lastGeneratedSession!,
        availableMovies: moodFilteredMovies,
        newMood: sessionContext.moods,
        user: user,
        alreadySeenIds: seenMovieIds.union(sessionPassedMovieIds),
        sessionSize: sessionSize,
      );
    } else {
      // Step 3: Create new smart session
      if (useSmartOrdering) {
        DebugLogger.log("🎯 Creating new smart-ordered session");
        result = SmartSessionFlow.createBalancedSession(
          filteredMovies: moodFilteredMovies,
          mood: sessionContext.moods,
          user: user,
          sessionSize: sessionSize,
        );
      } else {
        // Fallback to original sorting method
        DebugLogger.log("📊 Using original sorting method");
        result = _sortAndScoreMovies(moodFilteredMovies, sessionContext.moods, user, sessionSize);
      }
    }
    
    // Update session tracking
    _lastSessionMood = sessionContext.moods;
    _lastGeneratedSession = result;
    _currentSwipeCount = 0;
    
    DebugLogger.log("🎬 Generated ${result.length} enhanced mood movies");
    DebugLogger.log("   Sample: ${result.take(3).map((m) => m.title).join(', ')}");
    
    // Log session analytics
    if (useSmartOrdering) {
      final analytics = SmartSessionFlow.getSessionAnalytics(result);
      DebugLogger.log("📊 Session analytics: $analytics");
    }
    
    return result;
  }
  
  /// Record a swipe to track user engagement with current session
  static void recordSwipe({
    required String movieId,
    required bool isLike,
  }) {
    _currentSwipeCount++;
    DebugLogger.log("👆 Swipe recorded: ${isLike ? 'LIKE' : 'PASS'} (count: $_currentSwipeCount)");
  }
  
  /// Check if current session should be reordered vs regenerated
  static bool _shouldReorderExistingSession(CurrentMood newMood) {
    if (_lastSessionMood == null || _lastGeneratedSession == null) {
      return false;
    }
    
    return SmartSessionFlow.shouldReorderVsRegenerate(
      previousMood: _lastSessionMood!,
      newMood: newMood,
      swipeCount: _currentSwipeCount,
    );
  }
  
  /// Reset session tracking (call when user starts completely new session)
  static void resetSessionTracking() {
    _lastSessionMood = null;
    _currentSwipeCount = 0;
    _lastGeneratedSession = null;
    DebugLogger.log("🔄 Session tracking reset");
  }
  
  /// Blended mood session generator with smart ordering
  static Future<List<Movie>> generateBlendedMoodSession({
    required UserProfile user,
    required List<Movie> movieDatabase,
    required List<CurrentMood> selectedMoods,
    required Set<String> seenMovieIds,
    required Set<String> sessionPassedMovieIds,
    int sessionSize = 30,
    bool useSmartOrdering = true,
  }) async {
    DebugLogger.log("🎭 Generating enhanced blended mood session for: ${selectedMoods.map((m) => m.displayName).join(' + ')}");
    
    final blendedMovies = _filterForBlendedMoods(
      movieDatabase,
      selectedMoods,
      seenMovieIds,
      sessionPassedMovieIds,
    );
    
    if (blendedMovies.isEmpty) {
      DebugLogger.log("⚠️ No movies found for blended moods, using fallback");
      return _getFallbackMovies(movieDatabase, seenMovieIds, sessionSize);
    }
    
    List<Movie> result;
    
    if (useSmartOrdering) {
      // Use smart ordering with first mood as primary
      result = SmartSessionFlow.createBalancedSession(
        filteredMovies: blendedMovies,
        mood: selectedMoods.first,
        user: user,
        sessionSize: sessionSize,
      );
    } else {
      // For blended moods, use first mood's criteria for scoring
      result = _sortAndScoreMovies(blendedMovies, selectedMoods.first, user, sessionSize);
    }
    
    DebugLogger.log("🎬 Generated ${result.length} enhanced blended mood movies");
    return result;
  }
  
  /// Group session generator with smart ordering
  static Future<List<Movie>> generateGroupSession({
    required List<UserProfile> groupMembers,
    required List<Movie> movieDatabase,
    required SessionContext sessionContext,
    required Set<String> seenMovieIds,
    int sessionSize = 25,
    bool useSmartOrdering = true,
  }) async {
    DebugLogger.log("👥 Generating enhanced shared mood pool for ${groupMembers.length} people: ${sessionContext.moods.displayName}");
    
    // Use enhanced filtering
    final moodFilteredMovies = EnhancedMoodEngine.filterByMoodCriteria(
      movieDatabase, 
      sessionContext.moods, 
      seenMovieIds, 
      <String>{}
    );
    
    if (moodFilteredMovies.isEmpty) {
      DebugLogger.log("⚠️ No movies found for group mood, using fallback");
      return _getFallbackMovies(movieDatabase, seenMovieIds, sessionSize);
    }
    
    List<Movie> result;
    
    if (useSmartOrdering) {
      // For groups, use the first user's profile but with stronger mainstream bias
      result = SmartSessionFlow.createBalancedSession(
        filteredMovies: moodFilteredMovies,
        mood: sessionContext.moods,
        user: groupMembers.first,
        sessionSize: sessionSize,
        popularityWeight: 0.5,  // Higher popularity weight for groups
        qualityWeight: 0.3,
        randomWeight: 0.2,
      );
    } else {
      result = _sortForGroupCompatibility(moodFilteredMovies, groupMembers, sessionSize);
    }
    
    DebugLogger.log("🎬 Generated ${result.length} enhanced shared movies for group");
    DebugLogger.log("   Everyone will see: ${result.take(3).map((m) => m.title).join(', ')}");
    
    return result;
  }
  
  // ========================================
  // ENHANCED BLENDED MOOD FILTERING
  // ========================================
  
  static List<Movie> _filterForBlendedMoods(
    List<Movie> movieDatabase,
    List<CurrentMood> selectedMoods,
    Set<String> seenMovieIds,
    Set<String> sessionPassedMovieIds,
  ) {
    final blendedMovies = <Movie>[];
    final excludedMovieIds = <String>{};
    excludedMovieIds.addAll(seenMovieIds);
    excludedMovieIds.addAll(sessionPassedMovieIds);
    
    for (final movie in movieDatabase) {
      if (excludedMovieIds.contains(movie.id)) continue;
      
      // Movie must match at least one of the selected moods using enhanced logic
      final matchesAnyMood = selectedMoods.any((mood) => 
          _isMovieValidForMood(movie, mood));
      
      if (matchesAnyMood) {
        blendedMovies.add(movie);
      }
    }
    
    return blendedMovies;
  }
  
  /// Helper method to check if movie matches mood (wrapper for enhanced engine)
  static bool _isMovieValidForMood(Movie movie, CurrentMood mood) {
    // Use the enhanced engine's public method
    final movieGenres = movie.genres.map((g) => g.toLowerCase()).toSet();
    final movieTags = movie.tags.map((t) => t.toLowerCase()).toSet();
    
    // Check anti-pattern exclusions first
    final excludedGenres = EnhancedMoodEngine.MOOD_EXCLUSIONS[mood];
    if (excludedGenres != null) {
      for (final excludedGenre in excludedGenres) {
        if (movieGenres.contains(excludedGenre.toLowerCase())) {
          return false; // This movie is excluded from this mood
        }
      }
    }
    
    // For Tier 3 moods, check exemplar list using movie title
    if (mood == CurrentMood.mindBending || mood == CurrentMood.twistEnding || mood == CurrentMood.cultClassic) {
      String? moodType;
      switch (mood) {
        case CurrentMood.mindBending:
          moodType = 'mind_bending';
          break;
        case CurrentMood.twistEnding:
          moodType = 'twist_ending';
          break;
        case CurrentMood.cultClassic:
          moodType = 'cult_classic';
          break;
        default:
          break;
      }
      
      if (moodType != null && EnhancedMoodEngine.isExemplarMovieByTitle(movie.title, moodType)) {
        return true; // Exemplar movies always match
      }
    }
    
    // Basic quality and safety checks
    final rating = movie.rating ?? 0;
    final voteCount = movie.voteCount ?? 0;
    if (voteCount < 10 && rating < 5.0) return false;
    
    // Basic mood matching logic (simplified version)
    switch (mood) {
      case CurrentMood.familyFun:
        return movieGenres.contains('family') || movieGenres.contains('animation');
      case CurrentMood.pureComedy:
        return movieGenres.contains('comedy') && movieTags.any((tag) => tag.contains('funny'));
      case CurrentMood.epicAction:
        return movieGenres.contains('action') && movieTags.any((tag) => tag.contains('action-packed'));
      case CurrentMood.scaryAndSuspenseful:
        return movieGenres.contains('horror') || 
               (movieGenres.contains('thriller') && movieTags.any((tag) => tag.contains('scary')));
      case CurrentMood.romantic:
        return movieGenres.contains('romance');
      case CurrentMood.sciFiFuture:
        return movieGenres.contains('science fiction');
      default:
        // For other moods, use basic genre matching
        return mood.preferredGenres.any((g) => movieGenres.contains(g.toLowerCase()));
    }
  }
  
  // ========================================
  // ORIGINAL SORTING AND SCORING (PRESERVED FOR COMPATIBILITY)
  // ========================================
  
  static List<Movie> _sortAndScoreMovies(List<Movie> movies, CurrentMood mood, UserProfile user, int sessionSize) {
    final scoredMovies = movies.map((movie) {
      double score = 0.0;
      
      // Base quality score
      score += (movie.rating ?? 0) * 10;
      score += (movie.voteCount ?? 0) / 1000;
      
      // Mood alignment score
      final movieGenres = movie.genres.map((g) => g.toLowerCase()).toSet();
      final moodGenres = mood.preferredGenres.map((g) => g.toLowerCase()).toSet();
      final genreOverlap = movieGenres.intersection(moodGenres).length;
      score += genreOverlap * 20;
      
      // Tag alignment score
      final movieTags = movie.tags.map((t) => t.toLowerCase()).toSet();
      final moodTags = mood.preferredVibes.map((v) => v.toLowerCase()).toSet();
      final tagOverlap = movieTags.intersection(moodTags).length;
      score += tagOverlap * 15;
      
      // User preference alignment based on liked movies
      try {
        final userGenres = _getUserPreferredGenres(user);
        if (userGenres.any((g) => movieGenres.contains(g.toLowerCase()))) {
          score += 10;
        }
      } catch (e) {
        // If user preferences not available, skip this scoring
      }
      
      // Recency bonus for newer movies
      final releaseYear = _extractYear(movie.releaseDate);
      if (releaseYear != null && releaseYear > 2010) {
        score += (releaseYear - 2010) * 0.5;
      }
      
      return MapEntry(movie, score);
    }).toList();
    
    // Sort by score (highest first)
    scoredMovies.sort((a, b) => b.value.compareTo(a.value));
    
    // Return top movies
    return scoredMovies
        .take(sessionSize)
        .map((entry) => entry.key)
        .toList();
  }
  
  static List<Movie> _sortForGroupCompatibility(List<Movie> movies, List<UserProfile> groupMembers, int sessionSize) {
    // For group sessions, prioritize movies that appeal to multiple members
    final scoredMovies = movies.map((movie) {
      double groupScore = 0.0;
      
      // Base quality
      groupScore += (movie.rating ?? 0) * 10;
      groupScore += (movie.voteCount ?? 0) / 1000;
      
      // Count how many group members would like this genre
      final movieGenres = movie.genres.map((g) => g.toLowerCase()).toSet();
      int membersWhoLikeGenre = 0;
      
      for (final member in groupMembers) {
        final memberGenres = _getUserPreferredGenres(member);
        if (memberGenres.any((g) => movieGenres.contains(g.toLowerCase()))) {
          membersWhoLikeGenre++;
        }
      }
      
      // Bonus for movies that appeal to more group members
      groupScore += (membersWhoLikeGenre / groupMembers.length) * 30;
      
      // Popularity bonus (groups often prefer recognizable movies)
      final votes = movie.voteCount ?? 0;
      if (votes > 500) groupScore += 15;
      if (votes > 1000) groupScore += 10;
      
      return MapEntry(movie, groupScore);
    }).toList();
    
    // Sort by group compatibility score
    scoredMovies.sort((a, b) => b.value.compareTo(a.value));
    
    return scoredMovies
        .take(sessionSize)
        .map((entry) => entry.key)
        .toList();
  }
  
  // ========================================
  // HELPER METHODS
  // ========================================
  
  static List<String> _getUserPreferredGenres(UserProfile user) {
    // Get user's top genres based on their scoring
    final sortedGenres = user.genreScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedGenres.take(3).map((entry) => entry.key).toList();
  }
  
  static int? _extractYear(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      final parts = dateString.split('-');
      if (parts.isNotEmpty) {
        return int.parse(parts[0]);
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return null;
  }
  
  static List<Movie> _getFallbackMovies(List<Movie> movieDatabase, Set<String> seenMovieIds, int sessionSize) {
    // Simple fallback: return high-quality movies that haven't been seen
    final fallbackMovies = movieDatabase
        .where((movie) => 
            !seenMovieIds.contains(movie.id) &&
            (movie.rating ?? 0) >= 6.5 &&
            (movie.voteCount ?? 0) >= 100)
        .toList();
    
    if (fallbackMovies.isEmpty) {
      // Last resort: any unseen movie
      return movieDatabase
          .where((movie) => !seenMovieIds.contains(movie.id))
          .take(sessionSize)
          .toList();
    }
    
    fallbackMovies.shuffle();
    return fallbackMovies.take(sessionSize).toList();
  }
  
  // ========================================
  // SESSION MANAGEMENT UTILITIES
  // ========================================
  
  /// Get current session analytics
  static Map<String, dynamic> getCurrentSessionAnalytics() {
    if (_lastGeneratedSession == null) {
      return {'error': 'No active session'};
    }
    
    final analytics = SmartSessionFlow.getSessionAnalytics(_lastGeneratedSession!);
    analytics['swipeCount'] = _currentSwipeCount;
    analytics['currentMood'] = _lastSessionMood?.displayName ?? 'Unknown';
    
    return analytics;
  }
  
  /// Check if mood change would trigger session reorder
  static bool wouldMoodChangeReorder(CurrentMood newMood) {
    if (_lastSessionMood == null) return false;
    
    return SmartSessionFlow.shouldReorderVsRegenerate(
      previousMood: _lastSessionMood!,
      newMood: newMood,
      swipeCount: _currentSwipeCount,
    );
  }
  
  /// Get session health score (0.0 to 1.0)
  /// Higher score means session is working well for user
  static double getSessionHealthScore() {
    if (_currentSwipeCount == 0) return 1.0;
    
    // This would need to be enhanced with actual like/pass ratio
    // For now, return a simple engagement score
    if (_currentSwipeCount < 5) return 1.0;
    if (_currentSwipeCount < 15) return 0.8;
    if (_currentSwipeCount < 25) return 0.6;
    return 0.4; // User has swiped through most of session
  }
}