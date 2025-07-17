// File: lib/services/trailer_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/debug_loader.dart';

class MovieTrailer {
  final String key; // YouTube video key
  final String name;
  final String type; // "Trailer", "Teaser", etc.
  final bool official;
  final int size; // Video quality

  MovieTrailer({
    required this.key,
    required this.name,
    required this.type,
    required this.official,
    required this.size,
  });

  factory MovieTrailer.fromJson(Map<String, dynamic> json) {
    return MovieTrailer(
      key: json['key'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      official: json['official'] ?? false,
      size: json['size'] ?? 720,
    );
  }

  // Get YouTube URL for external player
  String get youTubeUrl => 'https://www.youtube.com/watch?v=$key';
  
  // Get YouTube thumbnail
  String get thumbnailUrl => 'https://img.youtube.com/vi/$key/maxresdefault.jpg';
  
  // Check if this is a trailer
  bool get isTrailer => type.toLowerCase().contains('trailer');
}

class TrailerService {
  static const String apiKey = '44bda25cf25ee68657a9007f51199091';
  static const String baseUrl = 'https://api.themoviedb.org/3';
  
  // Cache to avoid repeated API calls
  static final Map<String, MovieTrailer?> _trailerCache = {};

  /// Fetch the best trailer for a movie using your movie ID
  /// This works with your existing movie database structure
  static Future<MovieTrailer?> getTrailerForMovie(String movieId) async {
    // Check cache first
    if (_trailerCache.containsKey(movieId)) {
      return _trailerCache[movieId];
    }

    try {
      // Convert your string ID to int for TMDB API
      final tmdbId = int.tryParse(movieId);
      if (tmdbId == null) {
        DebugLogger.log('Invalid movie ID: $movieId');
        _trailerCache[movieId] = null;
        return null;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/movie/$tmdbId/videos?api_key=$apiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final videos = data['results'] as List;
        
        // Filter to YouTube videos only and convert to MovieTrailer objects
        final trailers = videos
            .where((video) => video['site'] == 'YouTube')
            .map((video) => MovieTrailer.fromJson(video))
            .toList();

        if (trailers.isEmpty) {
          _trailerCache[movieId] = null;
          return null;
        }

        // Find the best trailer using smart logic
        final bestTrailer = _selectBestTrailer(trailers);
        _trailerCache[movieId] = bestTrailer;
        
        return bestTrailer;
      } else {
        DebugLogger.log('Failed to fetch trailers: ${response.statusCode}');
        _trailerCache[movieId] = null;
        return null;
      }
    } catch (e) {
      DebugLogger.log('Error fetching trailer for movie $movieId: $e');
      _trailerCache[movieId] = null;
      return null;
    }
  }

  /// Smart trailer selection logic
  static MovieTrailer _selectBestTrailer(List<MovieTrailer> trailers) {
    // Priority 1: Official trailers
    final officialTrailers = trailers
        .where((t) => t.official && t.isTrailer)
        .toList();
    
    if (officialTrailers.isNotEmpty) {
      officialTrailers.sort((a, b) => b.size.compareTo(a.size));
      return officialTrailers.first;
    }

    // Priority 2: Any trailers
    final anyTrailers = trailers
        .where((t) => t.isTrailer)
        .toList();
        
    if (anyTrailers.isNotEmpty) {
      anyTrailers.sort((a, b) => b.size.compareTo(a.size));
      return anyTrailers.first;
    }

    // Priority 3: Teasers
    final teasers = trailers
        .where((t) => t.type.toLowerCase().contains('teaser'))
        .toList();
        
    if (teasers.isNotEmpty) {
      teasers.sort((a, b) => b.size.compareTo(a.size));
      return teasers.first;
    }

    // Fallback: Any video
    trailers.sort((a, b) => b.size.compareTo(a.size));
    return trailers.first;
  }

  /// Clear the cache (useful for testing or memory management)
  static void clearCache() {
    _trailerCache.clear();
  }

  /// Check if trailer is cached
  static bool isTrailerCached(String movieId) {
    return _trailerCache.containsKey(movieId);
  }

  /// Get cached trailer without API call
  static MovieTrailer? getCachedTrailer(String movieId) {
    return _trailerCache[movieId];
  }
}