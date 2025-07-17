import 'dart:convert';
import 'package:flutter/services.dart';
import '../movie.dart';
import '../utils/debug_loader.dart';

class MovieDatabaseLoader {
  static List<Movie>? _cachedMovies;
  static DateTime? _lastLoadTime;
  
  /// Load movies from your JSON database file
  static Future<List<Movie>> loadMovieDatabase() async {
    // Cache movies for 1 hour to avoid repeated file loading
    if (_cachedMovies != null && _lastLoadTime != null) {
      final timeDiff = DateTime.now().difference(_lastLoadTime!);
      if (timeDiff.inHours < 1) {
        DebugLogger.log("📱 Using cached movie database (${_cachedMovies!.length} movies)");
        return _cachedMovies!;
      }
    }
    
    try {
      DebugLogger.log("📥 Loading movie database from JSON file...");
      
      // Load your generated JSON file
      final String jsonString = await rootBundle.loadString('assets/movies.json');
      
      if (jsonString.isEmpty) {
        throw Exception("movies.json file is empty");
      }
      
      final List<dynamic> jsonData = json.decode(jsonString);
      
      if (jsonData.isEmpty) {
        throw Exception("movies.json contains no movie data");
      }
      
      DebugLogger.log("📊 Raw JSON contains ${jsonData.length} movie entries");
      
      final movies = <Movie>[];
      int skippedCount = 0;
      
      for (int i = 0; i < jsonData.length; i++) {
        try {
          final movieJson = jsonData[i];
          
          // Validate required fields before creating Movie object
          if (movieJson['id'] == null || movieJson['id'].toString().isEmpty) {
            skippedCount++;
            continue;
          }
          
          if (movieJson['title'] == null || movieJson['title'].toString().isEmpty) {
            skippedCount++;
            continue;
          }
          
          final movie = Movie.fromJson(movieJson);
          
          // Additional filtering for quality
          if (movie.posterUrl.isNotEmpty &&
              movie.title.isNotEmpty &&
              movie.overview.isNotEmpty &&
              movie.genres.isNotEmpty) {
            movies.add(movie);
          } else {
            skippedCount++;
          }
          
        } catch (e) {
          DebugLogger.log("⚠️ Error parsing movie at index $i: $e");
          skippedCount++;
          continue;
        }
      }
      
      if (movies.isEmpty) {
        throw Exception("No valid movies found in JSON file after parsing and filtering");
      }
      
      _cachedMovies = movies;
      _lastLoadTime = DateTime.now();
      
      DebugLogger.log("✅ Successfully loaded ${movies.length} movies from database");
      if (skippedCount > 0) {
        DebugLogger.log("⚠️ Skipped $skippedCount invalid movie entries");
      }
      DebugLogger.log("🎬 Sample movie: ${movies.first.title}");
      DebugLogger.log("🏷️ Sample genres: ${movies.first.genres}");
      DebugLogger.log("🎭 Sample tags: ${movies.first.tags}");
      
      return movies;
      
    } catch (e) {
      DebugLogger.log("❌ CRITICAL ERROR loading movie database: $e");
      DebugLogger.log("📁 Please check that assets/movies.json exists and is properly formatted");
      
      // ✅ NO MORE SAMPLE MOVIES FALLBACK - Return empty list instead
      _cachedMovies = <Movie>[];
      _lastLoadTime = DateTime.now();
      
      // Return empty list - let the UI handle this gracefully
      return <Movie>[];
    }
  }
  
  /// Get movies by specific criteria for recommendations
  static List<Movie> getMoviesByGenres(
    List<Movie> movieDatabase, 
    List<String> genres, 
    {int limit = 50}
  ) {
    final filtered = movieDatabase.where((movie) =>
      movie.genres.any((genre) => genres.contains(genre))
    ).toList();
    
    filtered.shuffle();
    return filtered.take(limit).toList();
  }
  
  /// Get movies by specific vibes/tags
  static List<Movie> getMoviesByVibes(
    List<Movie> movieDatabase, 
    List<String> vibes, 
    {int limit = 50}
  ) {
    final filtered = movieDatabase.where((movie) =>
      movie.tags.any((tag) => vibes.contains(tag))
    ).toList();
    
    filtered.shuffle();
    return filtered.take(limit).toList();
  }
  
  /// Get movies by actor
  static List<Movie> getMoviesByActor(
    List<Movie> movieDatabase, 
    String actor, 
    {int limit = 20}
  ) {
    final filtered = movieDatabase.where((movie) =>
      movie.cast.any((castMember) => 
        castMember.toLowerCase().contains(actor.toLowerCase()))
    ).toList();
    
    filtered.shuffle();
    return filtered.take(limit).toList();
  }
  
  /// Get high-quality movies (high rating and vote count)
  static List<Movie> getHighQualityMovies(
    List<Movie> movieDatabase, 
    {double minRating = 7.5, int minVotes = 1000, int limit = 100}
  ) {
    final filtered = movieDatabase.where((movie) =>
      movie.rating != null &&
      movie.rating! >= minRating &&
      movie.voteCount != null &&
      movie.voteCount! >= minVotes
    ).toList();
    
    // Sort by quality score
    filtered.sort((a, b) => b.qualityScore.compareTo(a.qualityScore));
    
    return filtered.take(limit).toList();
  }
  
  /// Get movies from specific time periods
  static List<Movie> getMoviesByDecade(
    List<Movie> movieDatabase, 
    String decade, 
    {int limit = 50}
  ) {
    final filtered = movieDatabase.where((movie) =>
      movie.decade == decade
    ).toList();
    
    filtered.shuffle();
    return filtered.take(limit).toList();
  }
  
  /// Get movies by runtime category
  static List<Movie> getMoviesByRuntime(
    List<Movie> movieDatabase, 
    String runtimeCategory, 
    {int limit = 50}
  ) {
    final filtered = movieDatabase.where((movie) =>
      movie.runtimeCategory == runtimeCategory
    ).toList();
    
    filtered.shuffle();
    return filtered.take(limit).toList();
  }
  
  /// Search movies by title or overview keywords
  static List<Movie> searchMovies(
    List<Movie> movieDatabase, 
    String query, 
    {int limit = 20}
  ) {
    final lowercaseQuery = query.toLowerCase();
    
    final filtered = movieDatabase.where((movie) =>
      movie.title.toLowerCase().contains(lowercaseQuery) ||
      movie.overview.toLowerCase().contains(lowercaseQuery) ||
      movie.cast.any((actor) => actor.toLowerCase().contains(lowercaseQuery))
    ).toList();
    
    // Sort by relevance (title matches first, then overview, then cast)
    filtered.sort((a, b) {
      final aTitle = a.title.toLowerCase().contains(lowercaseQuery) ? 3 : 0;
      final aOverview = a.overview.toLowerCase().contains(lowercaseQuery) ? 2 : 0;
      final aCast = a.cast.any((actor) => actor.toLowerCase().contains(lowercaseQuery)) ? 1 : 0;
      final aScore = aTitle + aOverview + aCast;
      
      final bTitle = b.title.toLowerCase().contains(lowercaseQuery) ? 3 : 0;
      final bOverview = b.overview.toLowerCase().contains(lowercaseQuery) ? 2 : 0;
      final bCast = b.cast.any((actor) => actor.toLowerCase().contains(lowercaseQuery)) ? 1 : 0;
      final bScore = bTitle + bOverview + bCast;
      
      return bScore.compareTo(aScore);
    });
    
    return filtered.take(limit).toList();
  }
  
  /// Get database statistics for debugging
  static Map<String, dynamic> getDatabaseStats(List<Movie> movieDatabase) {
    if (movieDatabase.isEmpty) {
      return {
        'totalMovies': 0,
        'error': 'No movies loaded',
      };
    }
    
    final totalMovies = movieDatabase.length;
    final moviesWithRating = movieDatabase.where((m) => m.rating != null).length;
    final highQualityMovies = movieDatabase.where((m) => m.isHighQuality).length;
    
    final genreCounts = <String, int>{};
    final vibeCounts = <String, int>{};
    final decadeCounts = <String, int>{};
    
    for (final movie in movieDatabase) {
      for (final genre in movie.genres) {
        genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
      }
      for (final vibe in movie.tags) {
        vibeCounts[vibe] = (vibeCounts[vibe] ?? 0) + 1;
      }
      decadeCounts[movie.decade] = (decadeCounts[movie.decade] ?? 0) + 1;
    }
    
    return {
      'totalMovies': totalMovies,
      'moviesWithRating': moviesWithRating,
      'highQualityMovies': highQualityMovies,
      'averageRating': moviesWithRating > 0 
          ? movieDatabase
              .where((m) => m.rating != null)
              .map((m) => m.rating!)
              .fold(0.0, (a, b) => a + b) / moviesWithRating
          : 0.0,
      'topGenres': genreCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))
        ..take(10),
      'topVibes': vibeCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))
        ..take(10),
      'decadeDistribution': decadeCounts,
    };
  }
  
  /// Clear cache (useful for testing)
  static void clearCache() {
    _cachedMovies = null;
    _lastLoadTime = null;
  }
}