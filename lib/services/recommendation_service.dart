import '../models/user_profile.dart';
import '../movie.dart';
import '../utils/debug_loader.dart';
import '../utils/movie_loader.dart';

extension MovieExtensions on Movie {
  static Movie empty() => Movie(
    id: '-1',  // String instead of int
    title: '',
    overview: '',
    genres: [],
    tags: [],
    posterUrl: '',
    cast: [],
  );
}

class RecommendationService {
  /// Main method to get movie recommendations for two users
  static Future<List<Movie>> getRecommendationsForPair({
    required UserProfile user1,
    required UserProfile user2,
    required List<Movie> allMovies, // Keep for backwards compatibility
    int maxRecommendations = 10,
  }) async {
    try {
      DebugLogger.log("🎬 Generating recommendations for ${user1.name} & ${user2.name}");
      
      // Load full movie database instead of using limited allMovies
      DebugLogger.log("📚 Loading full movie database...");
      final fullMovieDatabase = await MovieDatabaseLoader.loadMovieDatabase();
      
      if (fullMovieDatabase.isEmpty) {
        DebugLogger.log("❌ Movie database is empty, using fallback movies");
        return allMovies.take(maxRecommendations).toList();
      }
      
      DebugLogger.log("📊 Loaded ${fullMovieDatabase.length} movies from database");
      
      // Get shared movies as foundation
      final sharedMovieIds = user1.likedMovieIds.intersection(user2.likedMovieIds);
      final sharedMovies = fullMovieDatabase.where((movie) {
        return sharedMovieIds.contains(int.parse(movie.id));
      }).toList();
      
      DebugLogger.log("📊 Found ${sharedMovies.length} shared movies from ${sharedMovieIds.length} shared IDs");
      
      List<Movie> recommendations = [];
      
      // Strategy 1: Similar to shared movies (primary)
      if (sharedMovies.isNotEmpty) {
        final excludeMovieIdsAsStrings = user1.likedMovieIds.union(user2.likedMovieIds).map((id) => id.toString()).toSet();
        final similarToShared = await _findSimilarToSharedMovies(
          sharedMovies, 
          fullMovieDatabase, // Use full database
          excludeMovieIdsAsStrings,
        );
        recommendations.addAll(similarToShared);
        DebugLogger.log("🔍 Found ${similarToShared.length} movies similar to shared favorites");
      }
      
      // Strategy 2: Discovered preferences from behavior
      if (recommendations.length < maxRecommendations) {
        final excludeMovieIdsAsStrings = user1.likedMovieIds.union(user2.likedMovieIds).map((id) => id.toString()).toSet();
        final behaviorBased = await _findByDiscoveredPreferences(
          user1,
          user2,
          fullMovieDatabase, // Use full database
          excludeMovieIdsAsStrings,
        );
        recommendations.addAll(behaviorBased);
        DebugLogger.log("🧠 Found ${behaviorBased.length} movies from discovered preferences");
      }
      
      // Strategy 3: Popular in overlapping genres (fallback)
      if (recommendations.length < maxRecommendations) {
        final excludeMovieIdsAsStrings = user1.likedMovieIds.union(user2.likedMovieIds).map((id) => id.toString()).toSet();
        final genreBased = await _findPopularInSharedGenres(
          user1,
          user2,
          fullMovieDatabase, // Use full database
          excludeMovieIdsAsStrings,
        );
        recommendations.addAll(genreBased);
        DebugLogger.log("🎭 Found ${genreBased.length} popular movies in shared genres");
      }
      
      // Strategy 4: High-quality movies as final fallback
      if (recommendations.length < 3) {
        final excludeMovieIdsAsStrings = user1.likedMovieIds.union(user2.likedMovieIds).map((id) => id.toString()).toSet();
        final highQualityMovies = MovieDatabaseLoader.getHighQualityMovies(
          fullMovieDatabase,
          limit: 10,
        ).where((movie) => !excludeMovieIdsAsStrings.contains(movie.id)).toList();
        
        recommendations.addAll(highQualityMovies);
        DebugLogger.log("⭐ Added ${highQualityMovies.length} high-quality movies as fallback");
      }
      
      // Remove duplicates and limit results
      final uniqueRecommendations = recommendations.toSet().toList();
      final finalRecommendations = uniqueRecommendations.take(maxRecommendations).toList();
      
      DebugLogger.log("✨ Final recommendations: ${finalRecommendations.length} movies");
      return finalRecommendations;
      
    } catch (e) {
      DebugLogger.log("❌ Error generating recommendations: $e");
      return [];
    }
  }
  
  /// Strategy 1: Find movies similar to the ones both users liked
  static Future<List<Movie>> _findSimilarToSharedMovies(
    List<Movie> sharedMovies,
    List<Movie> allMovies,
    Set<String> excludeMovieIds,
  ) async {
    // Analyze patterns in shared movies
    final sharedGenres = <String>{};
    final sharedTags = <String>{};
    final genreFrequency = <String, int>{};
    final tagFrequency = <String, int>{};
    
    for (final movie in sharedMovies) {
      for (final genre in movie.genres) {
        sharedGenres.add(genre);
        genreFrequency[genre] = (genreFrequency[genre] ?? 0) + 1;
      }
      for (final tag in movie.tags) {
        sharedTags.add(tag);
        tagFrequency[tag] = (tagFrequency[tag] ?? 0) + 1;
      }
    }
    
    // Find movies that match the patterns from shared movies
    final candidates = allMovies.where((movie) {
      // Skip movies they've already liked
      if (excludeMovieIds.contains(movie.id)) return false;
      
      // Must have at least one genre in common with shared movies
      final hasSharedGenre = movie.genres.any((genre) => sharedGenres.contains(genre));
      if (!hasSharedGenre) return false;
      
      return true;
    }).toList();
    
    // Score candidates based on similarity to shared movies
    final scoredCandidates = candidates.map((movie) {
      double score = 0.0;
      
      // Score based on genre overlap (weighted by frequency in shared movies)
      for (final genre in movie.genres) {
        if (genreFrequency.containsKey(genre)) {
          score += genreFrequency[genre]! * 2.0; // Genre matches are important
        }
      }
      
      // Score based on tag/vibe overlap
      for (final tag in movie.tags) {
        if (tagFrequency.containsKey(tag)) {
          score += tagFrequency[tag]! * 1.5; // Tag matches are moderately important
        }
      }
      
      // Bonus for movies that match multiple shared patterns
      final genreOverlap = movie.genres.where((g) => sharedGenres.contains(g)).length;
      final tagOverlap = movie.tags.where((t) => sharedTags.contains(t)).length;
      if (genreOverlap >= 2) score += 3.0;
      if (tagOverlap >= 2) score += 2.0;
      
      return MapEntry(movie, score);
    }).where((entry) => entry.value > 0).toList();
    
    // Sort by score (highest first) and return top candidates
    scoredCandidates.sort((a, b) => b.value.compareTo(a.value));
    return scoredCandidates.take(8).map((entry) => entry.key).toList();
  }
  
  /// Strategy 2: Analyze what each user likes and find overlap patterns
  static Future<List<Movie>> _findByDiscoveredPreferences(
    UserProfile user1,
    UserProfile user2,
    List<Movie> allMovies,
    Set<String> excludeMovieIds,
  ) async {
    // Analyze user1's movie preferences
    final user1Genres = <String, int>{};
    final user1Tags = <String, int>{};
    
    for (final movieId in user1.likedMovieIds) {
      final movie = allMovies.firstWhere(
        (m) => m.id == movieId.toString(), 
        orElse: () => MovieExtensions.empty()
      );
      if (movie.id != '-1') {
        for (final genre in movie.genres) {
          user1Genres[genre] = (user1Genres[genre] ?? 0) + 1;
        }
        for (final tag in movie.tags) {
          user1Tags[tag] = (user1Tags[tag] ?? 0) + 1;
        }
      }
    }
    
    // Analyze user2's movie preferences  
    final user2Genres = <String, int>{};
    final user2Tags = <String, int>{};
    
    for (final movieId in user2.likedMovieIds) {
      final movie = allMovies.firstWhere(
        (m) => m.id == movieId.toString(), 
        orElse: () => MovieExtensions.empty()
      );
      if (movie.id != '-1') {
        for (final genre in movie.genres) {
          user2Genres[genre] = (user2Genres[genre] ?? 0) + 1;
        }
        for (final tag in movie.tags) {
          user2Tags[tag] = (user2Tags[tag] ?? 0) + 1;
        }
      }
    }
    
    // Find overlapping preferences (genres/tags both users like)
    final overlappingGenres = user1Genres.keys.toSet().intersection(user2Genres.keys.toSet());
    final overlappingTags = user1Tags.keys.toSet().intersection(user2Tags.keys.toSet());
    
    if (overlappingGenres.isEmpty && overlappingTags.isEmpty) {
      return [];
    }
    
    // Find movies that match both users' discovered preferences
    final candidates = allMovies.where((movie) {
      if (excludeMovieIds.contains(movie.id)) return false;
      
      // Must match at least one overlapping preference
      final hasOverlappingGenre = movie.genres.any((g) => overlappingGenres.contains(g));
      final hasOverlappingTag = movie.tags.any((t) => overlappingTags.contains(t));
      
      return hasOverlappingGenre || hasOverlappingTag;
    }).toList();
    
    // Score based on how well they match both users' preferences
    final scoredCandidates = candidates.map((movie) {
      double score = 0.0;
      
      // Score based on user1 preference strength
      for (final genre in movie.genres) {
        if (user1Genres.containsKey(genre)) {
          score += user1Genres[genre]! * 1.0;
        }
      }
      for (final tag in movie.tags) {
        if (user1Tags.containsKey(tag)) {
          score += user1Tags[tag]! * 0.8;
        }
      }
      
      // Score based on user2 preference strength  
      for (final genre in movie.genres) {
        if (user2Genres.containsKey(genre)) {
          score += user2Genres[genre]! * 1.0;
        }
      }
      for (final tag in movie.tags) {
        if (user2Tags.containsKey(tag)) {
          score += user2Tags[tag]! * 0.8;
        }
      }
      
      // Bonus for movies that hit multiple overlapping preferences
      final overlapGenreCount = movie.genres.where((g) => overlappingGenres.contains(g)).length;
      final overlapTagCount = movie.tags.where((t) => overlappingTags.contains(t)).length;
      score += overlapGenreCount * 2.0;
      score += overlapTagCount * 1.5;
      
      return MapEntry(movie, score);
    }).where((entry) => entry.value > 0).toList();
    
    scoredCandidates.sort((a, b) => b.value.compareTo(a.value));
    return scoredCandidates.take(6).map((entry) => entry.key).toList();
  }
  
  /// Strategy 3: Find popular movies in genres both users have shown interest in
  static Future<List<Movie>> _findPopularInSharedGenres(
    UserProfile user1,
    UserProfile user2,
    List<Movie> allMovies,
    Set<String> excludeMovieIds,
  ) async {
    // Get genres from user preferences first (if they exist)
    Set<String> sharedGenres = user1.preferredGenres.intersection(user2.preferredGenres);
    
    // If no explicit preferences, infer from liked movies
    if (sharedGenres.isEmpty) {
      final user1LikedGenres = <String>{};
      final user2LikedGenres = <String>{};
      
      // Extract genres from user1's liked movies
      for (final movieId in user1.likedMovieIds) {
        final movie = allMovies.firstWhere(
          (m) => m.id == movieId.toString(), 
          orElse: () => MovieExtensions.empty()
        );
        if (movie.id != '-1') {
          user1LikedGenres.addAll(movie.genres);
        }
      }
      
      // Extract genres from user2's liked movies
      for (final movieId in user2.likedMovieIds) {
        final movie = allMovies.firstWhere(
          (m) => m.id == movieId.toString(), 
          orElse: () => MovieExtensions.empty()
        );
        if (movie.id != '-1') {
          user2LikedGenres.addAll(movie.genres);
        }
      }
      
      sharedGenres = user1LikedGenres.intersection(user2LikedGenres);
    }
    
    if (sharedGenres.isEmpty) return [];
    
    // Find movies in shared genres that neither user has liked
    final candidates = allMovies.where((movie) {
      if (excludeMovieIds.contains(movie.id)) return false;
      return movie.genres.any((genre) => sharedGenres.contains(genre));
    }).toList();
    
    // Simple popularity scoring (could be enhanced with actual ratings/popularity data)
    // For now, score by how many shared genres the movie has
    final scoredCandidates = candidates.map((movie) {
      final genreMatches = movie.genres.where((g) => sharedGenres.contains(g)).length;
      return MapEntry(movie, genreMatches.toDouble());
    }).toList();
    
    scoredCandidates.sort((a, b) => b.value.compareTo(a.value));
    return scoredCandidates.take(5).map((entry) => entry.key).toList();
  }
  
  /// Get a compatibility score for a specific movie between two users
  static double getMovieCompatibilityScore(
    Movie movie,
    UserProfile user1,
    UserProfile user2,
  ) {
    double score = 0.0;
    
    // Check if movie matches user preferences
    final user1GenreMatches = movie.genres.where((g) => user1.preferredGenres.contains(g)).length;
    final user1VibeMatches = movie.tags.where((t) => user1.preferredVibes.contains(t)).length;
    
    final user2GenreMatches = movie.genres.where((g) => user2.preferredGenres.contains(g)).length;
    final user2VibeMatches = movie.tags.where((t) => user2.preferredVibes.contains(t)).length;
    
    // Score based on preference matches
    score += (user1GenreMatches + user2GenreMatches) * 2.0;
    score += (user1VibeMatches + user2VibeMatches) * 1.5;
    
    // Bonus if both users have matches
    if (user1GenreMatches > 0 && user2GenreMatches > 0) score += 3.0;
    if (user1VibeMatches > 0 && user2VibeMatches > 0) score += 2.0;
    
    return score;
  }

  /// Future method for solo recommendations (home screen use)
  static Future<List<Movie>> getSoloRecommendations({
    required UserProfile user,
    int maxRecommendations = 15,
  }) async {
    try {
      DebugLogger.log("🎯 Generating solo recommendations for ${user.name}");
      
      // Load full movie database
      final fullMovieDatabase = await MovieDatabaseLoader.loadMovieDatabase();
      
      if (fullMovieDatabase.isEmpty) {
        DebugLogger.log("❌ Movie database is empty");
        return [];
      }
      
      final excludeMovieIdsAsStrings = user.likedMovieIds.map((id) => id.toString()).toSet();
      List<Movie> recommendations = [];
      
      // Strategy 1: Movies similar to user's favorites
      if (user.likedMovieIds.isNotEmpty) {
        final userFavorites = fullMovieDatabase.where((movie) {
          return user.likedMovieIds.contains(int.parse(movie.id));
        }).toList();
        
        if (userFavorites.isNotEmpty) {
          final similarMovies = await _findSimilarToSharedMovies(
            userFavorites,
            fullMovieDatabase,
            excludeMovieIdsAsStrings,
          );
          recommendations.addAll(similarMovies);
        }
      }
      
      // Strategy 2: Movies in user's preferred genres
      if (recommendations.length < maxRecommendations && user.preferredGenres.isNotEmpty) {
        final genreMovies = MovieDatabaseLoader.getMoviesByGenres(
          fullMovieDatabase,
          user.preferredGenres.toList(),
          limit: 20,
        ).where((movie) => !excludeMovieIdsAsStrings.contains(movie.id)).toList();
        
        recommendations.addAll(genreMovies);
      }
      
      // Strategy 3: Movies with user's preferred vibes
      if (recommendations.length < maxRecommendations && user.preferredVibes.isNotEmpty) {
        final vibeMovies = MovieDatabaseLoader.getMoviesByVibes(
          fullMovieDatabase,
          user.preferredVibes.toList(),
          limit: 20,
        ).where((movie) => !excludeMovieIdsAsStrings.contains(movie.id)).toList();
        
        recommendations.addAll(vibeMovies);
      }
      
      // Strategy 4: High-quality movies as fallback
      if (recommendations.length < maxRecommendations) {
        final highQualityMovies = MovieDatabaseLoader.getHighQualityMovies(
          fullMovieDatabase,
          limit: 10,
        ).where((movie) => !excludeMovieIdsAsStrings.contains(movie.id)).toList();
        
        recommendations.addAll(highQualityMovies);
      }
      
      // Remove duplicates and limit results
      final uniqueRecommendations = recommendations.toSet().toList();
      final finalRecommendations = uniqueRecommendations.take(maxRecommendations).toList();
      
      DebugLogger.log("✨ Solo recommendations: ${finalRecommendations.length} movies");
      return finalRecommendations;
      
    } catch (e) {
      DebugLogger.log("❌ Error generating solo recommendations: $e");
      return [];
    }
  }
}