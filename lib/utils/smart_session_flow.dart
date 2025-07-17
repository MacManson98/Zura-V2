// Smart Session Flow Manager
// Balances randomness with quality to prevent showing only obscure movies
// Perfect for "tonight" viewing with mood-based reordering support

import 'dart:math';
import '../movie.dart';
import '../models/user_profile.dart';
import '../utils/debug_loader.dart';
import 'mood_engine.dart';

class SmartSessionFlow {
  
  // ========================================
  // INTELLIGENT SESSION ORDERING
  // ========================================
  
  /// Creates a balanced session that won't overwhelm users with obscure films
  /// Perfect for "tonight" viewing decisions
  static List<Movie> createBalancedSession({
    required List<Movie> filteredMovies,
    required CurrentMood mood,
    required UserProfile user,
    int sessionSize = 30,
    double popularityWeight = 0.3, // 30% weight to popularity
    double qualityWeight = 0.4,    // 40% weight to quality
    double randomWeight = 0.3,     // 30% weight to randomness
  }) {
    if (filteredMovies.isEmpty) return [];
    
    DebugLogger.log("🎯 Creating balanced session for ${mood.displayName}");
    DebugLogger.log("   Available movies: ${filteredMovies.length}");
    
    // Step 1: Categorize movies by recognition level
    final categorized = _categorizeMoviesByRecognition(filteredMovies);
    
    // Step 2: Create smart distribution
    final distribution = _calculateDistribution(sessionSize, categorized);
    
    // Step 3: Build session with strategic ordering
    final session = _buildStrategicSession(
      categorized,
      distribution,
      mood,
      user,
      popularityWeight,
      qualityWeight,
      randomWeight,
    );
    
    DebugLogger.log("🎬 Built session: ${session.length} movies");
    DebugLogger.log("   First 3: ${session.take(3).map((m) => '${m.title} (${m.voteCount} votes)').join(', ')}");
    
    return session;
  }
  
  /// Reorders an existing session when user's mood changes
  /// Keeps some movies from previous session for continuity
  static List<Movie> reorderForMoodChange({
    required List<Movie> currentSession,
    required List<Movie> availableMovies,
    required CurrentMood newMood,
    required UserProfile user,
    required Set<String> alreadySeenIds,
    int keepFromCurrent = 10, // Keep 10 movies from current session
    int sessionSize = 30,
  }) {
    DebugLogger.log("🔄 Reordering session for mood change to: ${newMood.displayName}");
    
    // Step 1: Keep some good movies from current session
    final currentToKeep = currentSession
        .where((movie) => !alreadySeenIds.contains(movie.id))
        .take(keepFromCurrent)
        .toList();
    
    // Step 2: Get fresh movies for new mood
    final newMovies = availableMovies
        .where((movie) => 
            !currentToKeep.any((existing) => existing.id == movie.id) &&
            !alreadySeenIds.contains(movie.id))
        .toList();
    
    // Step 3: Create blend of old and new
    final blendedSession = <Movie>[];
    
    // Add kept movies (rescored for new mood)
    blendedSession.addAll(currentToKeep);
    
    // Add new movies up to session size
    final newMoviesNeeded = sessionSize - blendedSession.length;
    if (newMovies.isNotEmpty && newMoviesNeeded > 0) {
      final newSession = createBalancedSession(
        filteredMovies: newMovies,
        mood: newMood,
        user: user,
        sessionSize: newMoviesNeeded,
      );
      blendedSession.addAll(newSession);
    }
    
    // Step 4: Shuffle to mix old and new
    blendedSession.shuffle(Random(DateTime.now().millisecondsSinceEpoch));
    
    DebugLogger.log("🔄 Reordered session: kept ${currentToKeep.length}, added ${blendedSession.length - currentToKeep.length}");
    
    return blendedSession.take(sessionSize).toList();
  }
  
  // ========================================
  // MOVIE CATEGORIZATION BY RECOGNITION
  // ========================================
  
  static Map<String, List<Movie>> _categorizeMoviesByRecognition(List<Movie> movies) {
    final categories = <String, List<Movie>>{
      'mainstream': <Movie>[],     // 1000+ votes, 7.0+ rating
      'popular': <Movie>[],        // 500+ votes, 6.5+ rating  
      'quality': <Movie>[],        // 100+ votes, 6.0+ rating
      'niche': <Movie>[],          // 50+ votes, any rating
      'obscure': <Movie>[],        // < 50 votes
    };
    
    for (final movie in movies) {
      final votes = movie.voteCount ?? 0;
      final rating = movie.rating ?? 0;
      
      if (votes >= 1000 && rating >= 7.0) {
        categories['mainstream']!.add(movie);
      } else if (votes >= 500 && rating >= 6.5) {
        categories['popular']!.add(movie);
      } else if (votes >= 100 && rating >= 6.0) {
        categories['quality']!.add(movie);
      } else if (votes >= 50) {
        categories['niche']!.add(movie);
      } else {
        categories['obscure']!.add(movie);
      }
    }
    
    DebugLogger.log("📊 Movie categorization:");
    categories.forEach((category, movieList) {
      DebugLogger.log("   $category: ${movieList.length}");
    });
    
    return categories;
  }
  
  // ========================================
  // SMART DISTRIBUTION CALCULATION
  // ========================================
  
  static Map<String, int> _calculateDistribution(int sessionSize, Map<String, List<Movie>> categories) {
    final distribution = <String, int>{};
    final availableCounts = categories.map((key, value) => MapEntry(key, value.length));
    
    // Base distribution percentages for a balanced "tonight" experience
    final basePercentages = {
      'mainstream': 0.35,  // 35% - Easy, recognizable choices
      'popular': 0.25,     // 25% - Well-known but not obvious
      'quality': 0.25,     // 25% - Hidden gems with good ratings
      'niche': 0.10,       // 10% - More adventurous picks
      'obscure': 0.05,     // 5% - True discoveries
    };
    
    // Calculate ideal counts
    for (final category in basePercentages.keys) {
      final idealCount = (sessionSize * basePercentages[category]!).round();
      final availableCount = availableCounts[category] ?? 0;
      distribution[category] = min(idealCount, availableCount);
    }
    
    // Redistribute if some categories are empty
    final totalAllocated = distribution.values.fold(0, (sum, count) => sum + count);
    final remaining = sessionSize - totalAllocated;
    
    if (remaining > 0) {
      // Give remaining slots to categories with available movies
      final categoriesWithMovies = categories.entries
          .where((entry) => entry.value.isNotEmpty)
          .map((entry) => entry.key)
          .toList();
      
      for (int i = 0; i < remaining && categoriesWithMovies.isNotEmpty; i++) {
        final category = categoriesWithMovies[i % categoriesWithMovies.length];
        final availableCount = availableCounts[category] ?? 0;
        if (distribution[category]! < availableCount) {
          distribution[category] = distribution[category]! + 1;
        }
      }
    }
    
    DebugLogger.log("📋 Session distribution: ${distribution}");
    return distribution;
  }
  
  // ========================================
  // STRATEGIC SESSION BUILDING
  // ========================================
  
  static List<Movie> _buildStrategicSession(
    Map<String, List<Movie>> categories,
    Map<String, int> distribution,
    CurrentMood mood,
    UserProfile user,
    double popularityWeight,
    double qualityWeight,
    double randomWeight,
  ) {
    final session = <Movie>[];
    final usedMovieIds = <String>{};
    
    // Build session by category, applying smart selection within each
    for (final categoryEntry in distribution.entries) {
      final category = categoryEntry.key;
      final count = categoryEntry.value;
      final availableMovies = categories[category]!
          .where((movie) => !usedMovieIds.contains(movie.id))
          .toList();
      
      if (availableMovies.isEmpty || count == 0) continue;
      
      // Select movies from this category using smart algorithm
      final selectedFromCategory = _selectMoviesFromCategory(
        availableMovies,
        count,
        mood,
        user,
        category,
        popularityWeight,
        qualityWeight,
        randomWeight,
      );
      
      session.addAll(selectedFromCategory);
      usedMovieIds.addAll(selectedFromCategory.map((movie) => movie.id));
    }
    
    // Strategic ordering: Don't start with obscure movies
    return _applyStrategicOrdering(session);
  }
  
  static List<Movie> _selectMoviesFromCategory(
    List<Movie> movies,
    int count,
    CurrentMood mood,
    UserProfile user,
    String category,
    double popularityWeight,
    double qualityWeight,
    double randomWeight,
  ) {
    if (movies.isEmpty) return [];
    
    // Score each movie in this category
    final scoredMovies = movies.map((movie) {
      double score = 0.0;
      
      // Popularity component
      final popularity = _calculatePopularityScore(movie);
      score += popularity * popularityWeight;
      
      // Quality component
      final quality = _calculateQualityScore(movie);
      score += quality * qualityWeight;
      
      // Mood alignment component
      final moodAlignment = _calculateMoodAlignment(movie, mood, user);
      score += moodAlignment * 0.3; // Fixed 30% for mood alignment
      
      // Random component (for variety)
      final random = Random(movie.title.hashCode).nextDouble();
      score += random * randomWeight;
      
      // Category-specific bonuses
      if (category == 'mainstream' || category == 'popular') {
        score += 0.1; // Slight bonus for recognizable movies
      }
      
      return MapEntry(movie, score);
    }).toList();
    
    // Sort by score and take top movies
    scoredMovies.sort((a, b) => b.value.compareTo(a.value));
    return scoredMovies.take(count).map((entry) => entry.key).toList();
  }
  
  // ========================================
  // SCORING ALGORITHMS
  // ========================================
  
  static double _calculatePopularityScore(Movie movie) {
    final votes = movie.voteCount ?? 0;
    // Logarithmic scale to prevent extremely popular movies from dominating
    return votes > 0 ? (log(votes + 1) / 10.0).clamp(0.0, 1.0) : 0.0;
  }
  
  static double _calculateQualityScore(Movie movie) {
    final rating = movie.rating ?? 0;
    // Normalize rating to 0-1 scale (5.0 = 0.0, 10.0 = 1.0)
    return ((rating - 5.0) / 5.0).clamp(0.0, 1.0);
  }
  
  static double _calculateMoodAlignment(Movie movie, CurrentMood mood, UserProfile user) {
    double score = 0.0;
    
    // Genre alignment
    final movieGenres = movie.genres.map((g) => g.toLowerCase()).toSet();
    final moodGenres = mood.preferredGenres.map((g) => g.toLowerCase()).toSet();
    final genreOverlap = movieGenres.intersection(moodGenres).length;
    score += genreOverlap * 0.3;
    
    // Tag alignment  
    final movieTags = movie.tags.map((t) => t.toLowerCase()).toSet();
    final moodTags = mood.preferredVibes.map((v) => v.toLowerCase()).toSet();
    final tagOverlap = movieTags.intersection(moodTags).length;
    score += tagOverlap * 0.4;
    
    // User preference alignment
    try {
      final userGenres = _getUserPreferredGenres(user);
      if (userGenres.any((g) => movieGenres.contains(g.toLowerCase()))) {
        score += 0.3;
      }
    } catch (e) {
      // If user preferences not available, skip this component
    }
    
    return score.clamp(0.0, 1.0);
  }
  
  static List<String> _getUserPreferredGenres(UserProfile user) {
    // Get user's top genres based on their scoring
    final sortedGenres = user.genreScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedGenres.take(3).map((entry) => entry.key).toList();
  }
  
  // ========================================
  // STRATEGIC ORDERING
  // ========================================
  
  static List<Movie> _applyStrategicOrdering(List<Movie> session) {
    if (session.length < 6) {
      session.shuffle(Random(DateTime.now().millisecondsSinceEpoch));
      return session;
    }
    
    // Ensure the first few movies are not too obscure
    final recognizable = <Movie>[];
    final obscure = <Movie>[];
    
    for (final movie in session) {
      final votes = movie.voteCount ?? 0;
      if (votes >= 100) {
        recognizable.add(movie);
      } else {
        obscure.add(movie);
      }
    }
    
    // Build strategic order
    final strategicSession = <Movie>[];
    
    // Start with recognizable movies (shuffled)
    recognizable.shuffle(Random(DateTime.now().millisecondsSinceEpoch));
    
    // Distribute movies strategically
    int recognizableIndex = 0;
    int obscureIndex = 0;
    
    for (int i = 0; i < session.length; i++) {
      // First 3 positions: definitely recognizable
      // After that: mix in obscure movies gradually
      if (i < 3 || (i % 4 != 0)) {
        if (recognizableIndex < recognizable.length) {
          strategicSession.add(recognizable[recognizableIndex++]);
        } else if (obscureIndex < obscure.length) {
          strategicSession.add(obscure[obscureIndex++]);
        }
      } else {
        if (obscureIndex < obscure.length) {
          strategicSession.add(obscure[obscureIndex++]);
        } else if (recognizableIndex < recognizable.length) {
          strategicSession.add(recognizable[recognizableIndex++]);
        }
      }
    }
    
    DebugLogger.log("🎯 Applied strategic ordering: recognizable first, obscure mixed in");
    return strategicSession;
  }
  
  // ========================================
  // MOOD CHANGE DETECTION & RESPONSE
  // ========================================
  
  /// Determines if a session should be reordered vs completely regenerated
  static bool shouldReorderVsRegenerate({
    required CurrentMood previousMood,
    required CurrentMood newMood,
    required int swipeCount,
  }) {
    // If user has swiped less than 5 movies, regenerate completely
    if (swipeCount < 5) return false;
    
    // If moods are very different, regenerate
    final moodDistance = _calculateMoodDistance(previousMood, newMood);
    if (moodDistance > 0.7) return false;
    
    // Otherwise, reorder existing session
    return true;
  }
  
  static double _calculateMoodDistance(CurrentMood mood1, CurrentMood mood2) {
    if (mood1 == mood2) return 0.0;
    
    // Calculate distance based on genre and vibe similarity
    final genres1 = mood1.preferredGenres.map((g) => g.toLowerCase()).toSet();
    final genres2 = mood2.preferredGenres.map((g) => g.toLowerCase()).toSet();
    final genreOverlap = genres1.intersection(genres2).length;
    final maxGenres = max(genres1.length, genres2.length);
    final genreSimilarity = maxGenres > 0 ? genreOverlap / maxGenres : 0.0;
    
    final vibes1 = mood1.preferredVibes.map((v) => v.toLowerCase()).toSet();
    final vibes2 = mood2.preferredVibes.map((v) => v.toLowerCase()).toSet();
    final vibeOverlap = vibes1.intersection(vibes2).length;
    final maxVibes = max(vibes1.length, vibes2.length);
    final vibeSimilarity = maxVibes > 0 ? vibeOverlap / maxVibes : 0.0;
    
    final averageSimilarity = (genreSimilarity + vibeSimilarity) / 2.0;
    return 1.0 - averageSimilarity;
  }
  
  // ========================================
  // SESSION ANALYTICS
  // ========================================
  
  /// Provides insights about the session composition
  static Map<String, dynamic> getSessionAnalytics(List<Movie> session) {
    if (session.isEmpty) return {'error': 'Empty session'};
    
    final analytics = <String, dynamic>{};
    
    // Basic stats
    analytics['totalMovies'] = session.length;
    analytics['averageRating'] = session
        .map((m) => m.rating ?? 0)
        .fold(0.0, (sum, rating) => sum + rating) / session.length;
    analytics['averageVotes'] = session
        .map((m) => m.voteCount ?? 0)
        .fold(0, (sum, votes) => sum + votes) / session.length;
    
    // Recognition distribution
    final recognition = _categorizeMoviesByRecognition(session);
    analytics['recognition'] = recognition.map((key, value) => MapEntry(key, value.length));
    
    // Release year distribution
    final decades = <String, int>{};
    for (final movie in session) {
      final year = _extractYear(movie.releaseDate);
      if (year != null) {
        final decade = '${(year ~/ 10) * 10}s';
        decades[decade] = (decades[decade] ?? 0) + 1;
      }
    }
    analytics['decades'] = decades;
    
    return analytics;
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
}