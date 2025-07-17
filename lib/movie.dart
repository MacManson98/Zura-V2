// File: lib/movie.dart (Enhanced Version with Streaming)

class Movie {
  final String id;
  final String title;
  final String posterUrl;
  final String overview;
  final List<String> cast;
  final List<String> genres;
  final List<String> tags; // Your vibe tags + TMDB keywords
  
  // 🆕 NEW: Enhanced fields from your database
  final List<String>? subGenres; // Your enhanced vibe system
  final int? runtime; // Runtime in minutes
  final double? rating; // TMDB vote_average
  final int? voteCount; // TMDB vote_count
  final String? releaseDate; // Release date
  final String? originalLanguage; // Original language
  final double? rottenTomatoesScore;
  final List<String> directors;
  final List<String> writers;
  
  // 🆕 NEW: Streaming availability fields
  final List<String> availableOn; // Free streaming platforms
  final List<String> rentOn; // Rental platforms
  final List<String> buyOn; // Purchase platforms
  final List<String> allServices; // All available services

  Movie({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.overview,
    required this.cast,
    required this.genres,
    required this.tags,
    this.subGenres,
    this.runtime,
    this.rating,
    this.voteCount,
    this.releaseDate,
    this.originalLanguage,
    this.rottenTomatoesScore,
    this.directors = const [],
    this.writers = const [],
    this.availableOn = const [],
    this.rentOn = const [],
    this.buyOn = const [],
    this.allServices = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'posterUrl': posterUrl,
      'overview': overview,
      'cast': cast,
      'genres': genres,
      'tags': tags,
      'subGenres': subGenres,
      'runtime': runtime,
      'rating': rating,
      'voteCount': voteCount,
      'releaseDate': releaseDate,
      'originalLanguage': originalLanguage,
      'directors': directors,
      'writers': writers,
      'available_on': availableOn,
      'rent_on': rentOn,
      'buy_on': buyOn,
      'all_services': allServices,
    };
  }

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      posterUrl: json['posterUrl'] ?? '',
      overview: json['overview'] ?? '',
      cast: _safeListFromJson(json['cast']),
      genres: _safeListFromJson(json['genres']),
      tags: _safeListFromJson(json['tags']),
      subGenres: json['subGenres'] != null ? _safeListFromJson(json['subGenres']) : null,
      runtime: json['runtime']?.toInt(),
      rating: json['rating']?.toDouble(),
      voteCount: json['voteCount']?.toInt(),
      releaseDate: json['releaseDate'],
      originalLanguage: json['originalLanguage'],
      rottenTomatoesScore: json['rottenTomatoesScore'],
      directors: _safeListFromJson(json['directors']),
      writers: _safeListFromJson(json['writers']),
      availableOn: _safeListFromJson(json['available_on']),
      rentOn: _safeListFromJson(json['rent_on']),
      buyOn: _safeListFromJson(json['buy_on']),
      allServices: _safeListFromJson(json['all_services']),
    );
  }

  // Helper method to safely convert JSON to List<String>
  static List<String> _safeListFromJson(dynamic jsonList) {
    if (jsonList == null) return [];
    if (jsonList is List) {
      return jsonList.map((item) => item?.toString() ?? '').where((item) => item.isNotEmpty).toList();
    }
    return [];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Movie && id == other.id);

  @override
  int get hashCode => id.hashCode;
  
  /// Helper methods for the learning engine
  
  /// Get quality score based on rating and vote count
  double get qualityScore {
    if (rating == null || voteCount == null) return 0.0;
    
    // Weighted score considering both rating and popularity
    final ratingWeight = (rating! / 10.0) * 0.7;
    final popularityWeight = (voteCount! > 1000 ? 1.0 : voteCount! / 1000.0) * 0.3;
    
    return ratingWeight + popularityWeight;
  }
  
  /// Check if this is a high-quality movie suitable for discovery
  bool get isHighQuality {
    return rating != null && 
           rating! >= 7.0 && 
           voteCount != null && 
           voteCount! >= 100;
  }
  
  /// Get runtime category for learning purposes
  String get runtimeCategory {
    if (runtime == null) return 'unknown';
    if (runtime! < 90) return 'short';
    if (runtime! < 130) return 'medium';
    return 'long';
  }
  
  /// Get rating category for learning purposes
  String get ratingCategory {
    if (rating == null) return 'unknown';
    if (rating! < 6.0) return 'low';
    if (rating! < 7.5) return 'medium';
    if (rating! < 8.5) return 'high';
    return 'exceptional';
  }
  
  /// Check if movie is in English (for language preference learning)
  bool get isEnglish => originalLanguage == 'en';
  
  /// Get decade for potential trend analysis
  String get decade {
    if (releaseDate == null || releaseDate!.length < 4) return 'unknown';
    try {
      final year = int.parse(releaseDate!.substring(0, 4));
      final decade = (year ~/ 10) * 10;
      return '${decade}s';
    } catch (e) {
      return 'unknown';
    }
  }
  
  // 🆕 NEW: Streaming helper methods
  
  /// Check if movie is available for free streaming
  bool get hasAvailableStreaming => availableOn.isNotEmpty;
  
  /// Check if movie can be rented
  bool get hasRentalOptions => rentOn.isNotEmpty;
  
  /// Check if movie can be purchased
  bool get hasPurchaseOptions => buyOn.isNotEmpty;
  
  /// Check if movie is available on any platform
  bool get hasAnyStreamingOptions => allServices.isNotEmpty;
  
  /// Get the primary streaming option (free > rent > buy)
  String? get primaryStreamingOption {
    if (availableOn.isNotEmpty) return availableOn.first;
    if (rentOn.isNotEmpty) return rentOn.first;
    if (buyOn.isNotEmpty) return buyOn.first;
    return null;
  }
  
  /// Get the best streaming option with type
  Map<String, String>? get bestStreamingOption {
    if (availableOn.isNotEmpty) {
      return {'platform': availableOn.first, 'type': 'free'};
    }
    if (rentOn.isNotEmpty) {
      return {'platform': rentOn.first, 'type': 'rent'};
    }
    if (buyOn.isNotEmpty) {
      return {'platform': buyOn.first, 'type': 'buy'};
    }
    return null;
  }

  factory Movie.empty() {
    return Movie(
      id: '',
      title: 'Unknown Movie',
      posterUrl: '',
      overview: '',
      cast: [],
      genres: [],
      tags: [],
      releaseDate: null,
    );
  }
}